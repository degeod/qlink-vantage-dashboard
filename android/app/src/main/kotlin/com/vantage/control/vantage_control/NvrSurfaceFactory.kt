package com.vantage.control.vantage_control

import android.content.Context
import android.graphics.Bitmap
import android.view.View
import com.ivyiot.ipclibrary.model.StreamMode
import com.ivyiot.ipclibrary.video.INVRLiveVideoView
import com.ivyiot.ipclibrary.video.VideoSurfaceViewNVR
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class NvrSurfaceFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val map = args as? Map<*, *>
        val channel = (map?.get("channel") as? Number)?.toInt() ?: 0
        val useSub = map?.get("sub") == true
        return NvrSurfaceView(context, channel, useSub)
    }
}

class NvrSurfaceView(
    context: Context,
    private val channel: Int,
    useSub: Boolean,
) : PlatformView, INVRLiveVideoView {
    private val surface = VideoSurfaceViewNVR(context, null)
    private var opened = false

    init {
        val nvr = NvrSession.nvr
        if (nvr != null && NvrSession.loggedIn) {
            val stream = if (useSub) StreamMode.STREAM_SUB else StreamMode.STREAM_MAIN
            surface.openNVRVideo(nvr, channel, stream, this)
            opened = true
        }
    }

    override fun getView(): View = surface

    override fun dispose() {
        if (opened) {
            surface.closeVideo(channel)
            opened = false
        }
    }

    override fun openVideoSuccess(cameraHandlerNo: Int) {}
    override fun onOpenVideoFail(errorCode: Int) {}
    override fun closeVideoSuccess() {}
    override fun closeVideoFail(errorCode: Int) {}
    override fun netFlowSpeedRefresh(speed: String?) {}
    override fun firstFrameDone(frame: Bitmap?) {}
}
