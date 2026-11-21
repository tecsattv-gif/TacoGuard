package com.tecsattv.tacoguard

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
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
                        Thread { listen() }.start()
                        result.success(true)
                    }
                    "write" -> {
                        val data = call.argument<ByteArray>("data") ?: ByteArray(0)
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

    /** O telefone liga ao tacógrafo (3 tentativas diferentes). */
    private fun connect(address: String) {
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
        val tries = listOf<() -> BluetoothSocket>(
            { dev.createRfcommSocketToServiceRecord(spp) },
            { dev.createInsecureRfcommSocketToServiceRecord(spp) },
            {
                dev.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                    .invoke(dev, 1) as BluetoothSocket
            },
        )
        var last = ""
        for ((i, make) in tries.withIndex()) {
            try {
                emit("state", "a ligar (${i + 1}/3)")
                val s = make()
                s.connect()
                socket = s
                emit("state", "connected")
                read(s)
                return
            } catch (e: Exception) {
                last = e.message ?: e.javaClass.simpleName
            }
        }
        emit("error", "connect: $last")
        emit("state", "disconnected")
    }

    /** O tacógrafo liga ao telefone (ele é o "mestre" na especificação). */
    private fun listen() {
        close()
        try {
            val ad = BluetoothAdapter.getDefaultAdapter() ?: return
            val srv = ad.listenUsingRfcommWithServiceRecord("TacoGuard", spp)
            server = srv
            emit("state", "à espera do tacógrafo")
            val s = srv.accept(120000)
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

    fun close() {
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
