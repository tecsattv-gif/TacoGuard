package com.tecsattv.tacoguard

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.Semaphore
import java.util.concurrent.TimeUnit

/**
 * 1.11.0: ligação Bluetooth ao tacógrafo inteligente (interface ITS,
 * Regulamento (UE) 2016/799, Anexo IC, Apêndice 13): perfil SPP (porta
 * série). Aqui só se abre a ligação e se passam os bytes; as mensagens são
 * montadas e lidas no Dart (lib/tacho_link.dart).
 */
class TachoBt(private val activity: Activity, messenger: BinaryMessenger) {
    private val spp: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private var socket: BluetoothSocket? = null
    private var server: BluetoothServerSocket? = null
    private var sink: EventChannel.EventSink? = null
    private val ui = Handler(Looper.getMainLooper())

    init {
        EventChannel(messenger, "tacoguard/bt/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, s: EventChannel.EventSink?) {
                    sink = s
                }

                override fun onCancel(args: Any?) {
                    sink = null
                }
            })
        MethodChannel(messenger, "tacoguard/bt").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "perm" -> result.success(askPerm())
                    "bonded" -> result.success(bonded())
                    "connect" -> {
                        val addr = call.argument<String>("address") ?: ""
                        Thread { connect(addr) }.start()
                        result.success(true)
                    }
                    "listen" -> {
                        Thread { listen(120000) }.start()
                        result.success(true)
                    }
                    "write" -> {
                        val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                        if (gatt != null) {
                            bleQueue.offer(Pair(null, data))
                            result.success(true)
                        } else {
                            Thread {
                                try {
                                    socket?.outputStream?.write(data)
                                    socket?.outputStream?.flush()
                                } catch (e: Exception) {
                                    emit("error", "write: ${e.message}")
                                }
                            }.start()
                            result.success(socket != null)
                        }
                    }
                    // 1.11.4: escreve num canal LE pelo UUID (créditos ou dados).
                    "writeChar" -> {
                        val u = UUID.fromString(call.argument<String>("uuid") ?: "")
                        val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                        bleQueue.offer(Pair(u, data))
                        result.success(gatt != null)
                    }
                    "target" -> {
                        val i = call.argument<Int>("index") ?: 0
                        val c = chars.getOrNull(i)
                        if (c != null) {
                            txChar = c
                            emit("info", "enviar pelo canal ${i + 1} (${c.uuid})")
                        }
                        result.success(c != null)
                    }
                    "disconnect" -> {
                        close()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: SecurityException) {
                result.error("perm", e.message, null)
            } catch (e: Exception) {
                result.error("bt", e.message, null)
            }
        }
    }

    private fun askPerm(): Boolean {
        if (Build.VERSION.SDK_INT < 31) return true
        val need = arrayOf(Manifest.permission.BLUETOOTH_CONNECT, Manifest.permission.BLUETOOTH_SCAN)
            .filter { activity.checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (need.isNotEmpty()) activity.requestPermissions(need.toTypedArray(), 7701)
        return need.isEmpty()
    }

    private fun bonded(): List<Map<String, String>> {
        val ad = BluetoothAdapter.getDefaultAdapter() ?: return emptyList()
        return ad.bondedDevices.map { mapOf("name" to (it.name ?: ""), "address" to it.address) }
    }

    private fun emit(type: String, data: Any?) {
        ui.post {
            try {
                sink?.success(mapOf("type" to type, "data" to data))
            } catch (_: Exception) {
            }
        }
    }

    @Volatile private var busy = false

    /**
     * O telefone liga ao tacógrafo. 1.11.1: pergunta ao tacógrafo que
     * serviços tem (SDP) e tenta cada um; depois a porta série padrão e os
     * canais 1 a 6 direto. Se nada der, fica 90 s à espera de que o
     * tacógrafo ligue (na especificação ele é o "mestre").
     */
    private fun connect(address: String) {
        if (busy) {
            emit("info", "já está a tentar ligar")
            return
        }
        busy = true
        try {
            close()
            val ad = BluetoothAdapter.getDefaultAdapter()
            if (ad == null) {
                emit("error", "sem Bluetooth")
                return
            }
            try {
                ad.cancelDiscovery()
            } catch (_: Exception) {
            }
            val dev = ad.getRemoteDevice(address)
            // Serviços que o tacógrafo anuncia.
            try {
                dev.fetchUuidsWithSdp()
                Thread.sleep(2500)
            } catch (_: Exception) {
            }
            val uuids = (dev.uuids ?: emptyArray()).map { it.uuid }
            emit("info", "serviços do tacógrafo: " +
                if (uuids.isEmpty()) "nenhum anunciado" else uuids.joinToString(", "))
            emit("info", "tipo: ${dev.type}  emparelhado: ${dev.bondState == 12}")
            // 1.11.2: tipo 2 = só Bluetooth LE (o DTCO 4.1 é assim): liga por
            // GATT. Tipo 3 (os dois): tenta LE primeiro.
            if (dev.type == BluetoothDevice.DEVICE_TYPE_LE ||
                dev.type == BluetoothDevice.DEVICE_TYPE_DUAL) {
                busy = false
                connectBle(dev)
                return
            }
            val tries = mutableListOf<Pair<String, () -> BluetoothSocket>>()
            for (u in uuids.distinct()) {
                tries.add("serviço $u" to { dev.createRfcommSocketToServiceRecord(u) })
                tries.add("serviço $u (inseguro)" to { dev.createInsecureRfcommSocketToServiceRecord(u) })
            }
            if (!uuids.contains(spp)) {
                tries.add("porta série" to { dev.createRfcommSocketToServiceRecord(spp) })
                tries.add("porta série (inseguro)" to { dev.createInsecureRfcommSocketToServiceRecord(spp) })
            }
            for (ch in 1..6) {
                tries.add("canal $ch" to {
                    dev.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        .invoke(dev, ch) as BluetoothSocket
                })
            }
            for ((i, t) in tries.withIndex()) {
                try {
                    emit("state", "a ligar (${i + 1}/${tries.size})")
                    val s = t.second()
                    s.connect()
                    socket = s
                    emit("info", "ligado por: ${t.first}")
                    emit("state", "connected")
                    busy = false
                    read(s)
                    return
                } catch (e: Exception) {
                    emit("info", "${t.first}: ${e.message ?: e.javaClass.simpleName}")
                }
            }
            emit("error", "o tacógrafo não aceitou a ligação; à espera de que ele ligue")
        } finally {
            busy = false
        }
        listen(90000)
    }

    /** O tacógrafo liga ao telefone (ele é o "mestre" na especificação). */
    private fun listen(ms: Int = 120000) {
        close()
        try {
            val ad = BluetoothAdapter.getDefaultAdapter() ?: return
            val srv = ad.listenUsingRfcommWithServiceRecord("TacoGuard", spp)
            server = srv
            emit("state", "à espera do tacógrafo")
            emit("info", "o telefone está visível como TacoGuard; ligue a partir do menu do tacógrafo, se houver")
            val s = srv.accept(ms)
            try {
                srv.close()
            } catch (_: Exception) {
            }
            server = null
            socket = s
            emit("state", "connected")
            read(s)
        } catch (e: Exception) {
            emit("error", "listen: ${e.message}")
            emit("state", "disconnected")
        }
    }

    private fun read(s: BluetoothSocket) {
        val buf = ByteArray(1024)
        try {
            val inp = s.inputStream
            while (true) {
                val n = inp.read(buf)
                if (n < 0) break
                if (n > 0) emit("data", buf.copyOf(n))
            }
        } catch (_: Exception) {
        }
        if (socket === s) socket = null
        emit("state", "disconnected")
    }


    // ---------- Bluetooth LE (1.11.2) ----------
    @Volatile private var gatt: BluetoothGatt? = null
    private var rxChar: BluetoothGattCharacteristic? = null
    private var txChar: BluetoothGattCharacteristic? = null
    private val chars = mutableListOf<BluetoothGattCharacteristic>()
    private val toEnable = ArrayDeque<BluetoothGattCharacteristic>()
    private val bleQueue = LinkedBlockingQueue<Pair<UUID?, ByteArray>>()
    private val writeDone = Semaphore(0)
    private var mtu = 23
    private var writer: Thread? = null

    private fun props(p: Int): String {
        val l = mutableListOf<String>()
        if (p and BluetoothGattCharacteristic.PROPERTY_READ != 0) l.add("read")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0) l.add("write")
        if (p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) l.add("writeNR")
        if (p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0) l.add("notify")
        if (p and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0) l.add("indicate")
        return l.joinToString("/")
    }

    // Serviços padrão do Bluetooth (não são os dados do tacógrafo).
    private fun isStd(u: UUID): Boolean {
        val s = u.toString().lowercase()
        return s.endsWith("-0000-1000-8000-00805f9b34fb") &&
            (s.startsWith("00001800") || s.startsWith("00001801") ||
                s.startsWith("0000180a") || s.startsWith("0000180f"))
    }

    private val cccd: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    private fun connectBle(dev: BluetoothDevice) {
        emit("state", "a ligar (Bluetooth LE)")
        val cb = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED) {
                    emit("info", "LE ligado (status $status); a pedir MTU e serviços")
                    try {
                        g.requestMtu(247)
                    } catch (_: Exception) {
                        g.discoverServices()
                    }
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                    emit("info", "LE desligado (status $status)")
                    try {
                        g.close()
                    } catch (_: Exception) {
                    }
                    if (gatt === g) gatt = null
                    writer?.interrupt()
                    emit("state", "disconnected")
                }
            }

            override fun onMtuChanged(g: BluetoothGatt, m: Int, status: Int) {
                mtu = m
                emit("info", "MTU $m")
                g.discoverServices()
            }

            override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
                var rx: BluetoothGattCharacteristic? = null
                var tx: BluetoothGattCharacteristic? = null
                for (sv in g.services) {
                    emit("info", "serviço ${sv.uuid}")
                    for (c in sv.characteristics) {
                        emit("info", "  car. ${c.uuid} [${props(c.properties)}]")
                    }
                }
                // 1.11.3: todos os canais dos serviços não padrão que
                // recebem (notify/indicate). Liga os avisos em todos (um de
                // cada vez) e o app testa por qual deles o tacógrafo responde.
                chars.clear()
                for (sv in g.services) {
                    if (isStd(sv.uuid)) continue
                    for (c in sv.characteristics) {
                        if (c.properties and (BluetoothGattCharacteristic.PROPERTY_NOTIFY or
                                BluetoothGattCharacteristic.PROPERTY_INDICATE) != 0) chars.add(c)
                    }
                }
                if (chars.isEmpty()) {
                    emit("error", "LE: não achei o canal de dados (ver lista de serviços)")
                    return
                }
                for ((i, c) in chars.withIndex()) emit("info", "canal ${i + 1}: ${c.uuid}")
                rxChar = chars[0]
                txChar = chars.firstOrNull {
                    it.properties and (BluetoothGattCharacteristic.PROPERTY_WRITE or
                        BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE) != 0
                } ?: chars[0]
                toEnable.clear()
                toEnable.addAll(chars)
                enableNext(g)
            }

            override fun onDescriptorWrite(g: BluetoothGatt, d: BluetoothGattDescriptor, status: Int) {
                emit("info", "avisos ligados em ${d.characteristic.uuid} (status $status)")
                enableNext(g)
            }

            @Deprecated("Android < 13")
            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
                @Suppress("DEPRECATION")
                val v = c.value ?: return
                got(c, v)
            }

            override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic, value: ByteArray) {
                got(c, value)
            }

            override fun onCharacteristicWrite(g: BluetoothGatt, c: BluetoothGattCharacteristic, status: Int) {
                if (status != 0) emit("info", "envio LE status $status")
                writeDone.release()
            }
        }
        try {
            gatt = if (Build.VERSION.SDK_INT >= 23)
                dev.connectGatt(activity, false, cb, BluetoothDevice.TRANSPORT_LE)
            else dev.connectGatt(activity, false, cb)
        } catch (e: Exception) {
            emit("error", "LE: ${e.message}")
            emit("state", "disconnected")
        }
    }

    private fun got(c: BluetoothGattCharacteristic, v: ByteArray) {
        // 1.11.4: vai com o canal (UUID) de onde veio.
        emit("rx", mapOf("uuid" to c.uuid.toString(), "data" to v.copyOf()))
    }

    /** Liga os avisos do próximo canal; no fim, fica pronto. */
    private fun enableNext(g: BluetoothGatt) {
        val c = toEnable.removeFirstOrNull()
        if (c == null) {
            emit("channels", chars.size)
            ready()
            return
        }
        g.setCharacteristicNotification(c, true)
        val d = c.getDescriptor(cccd)
        if (d == null) {
            enableNext(g)
            return
        }
        val v = if (c.properties and BluetoothGattCharacteristic.PROPERTY_INDICATE != 0 &&
            c.properties and BluetoothGattCharacteristic.PROPERTY_NOTIFY == 0)
            BluetoothGattDescriptor.ENABLE_INDICATION_VALUE
        else BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
        if (Build.VERSION.SDK_INT >= 33) {
            g.writeDescriptor(d, v)
        } else {
            @Suppress("DEPRECATION")
            d.value = v
            @Suppress("DEPRECATION")
            g.writeDescriptor(d)
        }
    }

    private fun ready() {
        bleQueue.clear()
        writer?.interrupt()
        writer = Thread {
            try {
                while (true) {
                    val item = bleQueue.take()
                    val data = item.second
                    val g = gatt ?: break
                    val c = (if (item.first != null) chars.firstOrNull { it.uuid == item.first } else null)
                        ?: txChar ?: break
                    val size = (mtu - 3).coerceAtLeast(20)
                    var i = 0
                    while (i < data.size) {
                        val part = data.copyOfRange(i, minOf(i + size, data.size))
                        val noResp = c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE == 0
                        val type = if (noResp) BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
                        else BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        if (Build.VERSION.SDK_INT >= 33) {
                            g.writeCharacteristic(c, part, type)
                        } else {
                            @Suppress("DEPRECATION")
                            c.value = part
                            c.writeType = type
                            @Suppress("DEPRECATION")
                            g.writeCharacteristic(c)
                        }
                        writeDone.tryAcquire(2, TimeUnit.SECONDS)
                        i += size
                    }
                }
            } catch (_: InterruptedException) {
            } catch (e: Exception) {
                emit("error", "envio LE: ${e.message}")
            }
        }
        writer?.start()
        emit("state", "connected")
    }

    fun close() {
        writer?.interrupt()
        writer = null
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
        try {
            server?.close()
        } catch (_: Exception) {
        }
        server = null
    }
}
