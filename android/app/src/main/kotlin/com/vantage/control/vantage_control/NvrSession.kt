package com.vantage.control.vantage_control

import com.ivyiot.ipclibrary.model.IvyNVR
import com.ivyiot.ipclibrary.model.NVRIPCInfo

/** Holds the official IvyIo NVR handle for Flutter + the surface view. */
object NvrSession {
    var nvr: IvyNVR? = null
    var channels: List<NVRIPCInfo> = emptyList()
    var loggedIn: Boolean = false
}
