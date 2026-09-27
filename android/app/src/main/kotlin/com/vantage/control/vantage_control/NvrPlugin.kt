package com.vantage.control.vantage_control

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.ivyio.sdk.DevType
import com.ivyio.sdk.Result
import com.ivyiot.ipclibrary.model.IvyNVR
import com.ivyiot.ipclibrary.model.NVRIPCInfo
import com.ivyiot.ipclibrary.sdk.ISdkCallback
import com.ivyiot.ipclibrary.sdk.SDKManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Thin wrapper around IvyIo's published Android SDK
 * (IVYIoT/android-app-sdk-demo: discovery + IvyNVR.loginDevice + getIPCListInfo).
 */
class NvrPlugin(private val appContext: Context) : MethodChannel.MethodCallHandler {
    private var sdkReady = false
    private val main = Handler(Looper.getMainLooper())

    private fun ok(result: MethodChannel.Result, value: Any?) {
        main.post { result.success(value) }
    }

    private fun fail(result: MethodChannel.Result, code: String, message: String) {
        main.post { result.error(code, message, null) }
    }

    private fun ensureSdk() {
        if (sdkReady) return
        SDKManager.getInstance().init(appContext)
        sdkReady = true
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "discover" -> {
                    ensureSdk()
                    val nodes = SDKManager.getInstance().discoveryDeviceInWLAN() ?: emptyArray()
                    val list = nodes
                        .filter { it.type == DevType.IVY_NVR || it.type == DevType.FOS_NVR }
                        .map { dev ->
                            mapOf(
                                "name" to (dev.name ?: ""),
                                "uid" to (dev.uid ?: ""),
                                "ip" to (dev.ip ?: ""),
                                "port" to dev.port,
                                "type" to dev.type,
                            )
                        }
                    result.success(list)
                }
                "login" -> {
                    ensureSdk()
                    val uid = call.argument<String>("uid")?.trim().orEmpty()
                    val user = call.argument<String>("user")?.trim().orEmpty()
                    val password = call.argument<String>("password") ?: ""
                    if (uid.isEmpty()) {
                        fail(result, "args", "UID ontbreekt. Zoek eerst in het LAN.")
                        return
                    }
                    NvrSession.nvr?.logout()
                    NvrSession.nvr?.destroy()
                    NvrSession.nvr = null
                    NvrSession.loggedIn = false
                    NvrSession.channels = emptyList()
                    val nvr = IvyNVR()
                    nvr.uid = uid
                    nvr.usrName = user.ifEmpty { "admin" }
                    nvr.password = resolvePassword(uid, password)
                    NvrSession.nvr = nvr
                    nvr.loginDevice(object : ISdkCallback<Any?> {
                        override fun onSuccess(res: Any?) {
                            nvr.getIPCListInfo(object : ISdkCallback<ArrayList<NVRIPCInfo>> {
                                override fun onSuccess(info: ArrayList<NVRIPCInfo>?) {
                                    NvrSession.channels = info?.toList() ?: emptyList()
                                    NvrSession.loggedIn = true
                                    ok(result, channelMaps())
                                }
                                override fun onError(errorCode: Int) {
                                    NvrSession.loggedIn = true
                                    NvrSession.channels = emptyList()
                                    ok(result, channelMaps())
                                }
                                override fun onLoginError(errorCode: Int) {
                                    fail(result, "login", ivyError(errorCode, "kanaallijst"))
                                }
                            })
                        }
                        override fun onError(errorCode: Int) {
                            fail(result, "login", ivyError(errorCode, "login"))
                        }
                        override fun onLoginError(errorCode: Int) {
                            fail(result, "login", ivyError(errorCode, "login"))
                        }
                    })
                }
                "channels" -> result.success(channelMaps())
                "logout" -> {
                    NvrSession.nvr?.logout()
                    NvrSession.nvr?.destroy()
                    NvrSession.nvr = null
                    NvrSession.loggedIn = false
                    NvrSession.channels = emptyList()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            fail(result, "sdk", e.message ?: "SDK-fout")
        }
    }

    private fun channelMaps(): List<Map<String, Any?>> =
        NvrSession.channels.map { ch ->
            mapOf(
                "channel" to ch.channel,
                "name" to (ch.devName ?: "Kanaal ${ch.channel}"),
                "online" to ch.isOnline,
                "ip" to (ch.ip ?: ""),
            )
        }

    /**
     * Ivy docs: default user is admin. Empty password unless UID char 22 is in
     * 89ABCDEF… — then SDKManager.getFactoryPassword (IvyCryptoJni).
     */
    private fun resolvePassword(uid: String, typed: String): String {
        if (typed.isNotEmpty()) return typed
        return try {
            SDKManager.getInstance().getFactoryPassword(uid).orEmpty()
        } catch (_: Exception) {
            ""
        }
    }

    private fun ivyError(code: Int, where: String): String {
        val meaning = when (code) {
            Result.OK -> "ok"
            Result.FAIL -> "mislukt"
            Result.HANDLE_ERR -> "handle-fout"
            Result.USR_OR_PWD_ERR ->
                "gebruikersnaam of wachtwoord fout. Zelfde login als de Foscam-app."
            Result.ARGS_ERR -> "argumentfout"
            Result.APITIME_ERR -> "API-tijd fout"
            Result.DENY -> "geweigerd"
            Result.LOCKED -> "NVR vergrendeld (te veel foute pogingen)"
            Result.MAX_USER -> "te veel gebruikers ingelogd"
            Result.TALK_OPENED_BY_OTHERS -> "spraak al open"
            Result.CANCEL_BY_USER -> "geannuleerd"
            Result.TIMEOUT -> "timeout"
            Result.UNSUPPORT -> "niet ondersteund"
            Result.UNKNOWN -> "onbekend"
            Result.OFFLINE -> "NVR offline"
            Result.OK_ON_RESET_STATE ->
                "NVR in reset-staat: eerst een wachtwoord instellen in de Foscam-app"
            Result.NO_PERMISSION -> "geen rechten"
            Result.DOWNLOADING -> "bezig met download"
            Result.RECORD_NOT_EXIST -> "opname bestaat niet"
            Result.RECORD_OPEN_FAIL -> "opname openen mislukt"
            Result.FAIL_BECAUSE_SMART_AI_ENABLED -> "Smart AI actief"
            else -> "onbekende SDK-code"
        }
        return "NVR-$where: $meaning ($code)"
    }
}
