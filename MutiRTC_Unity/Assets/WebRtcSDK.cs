
using System;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using MiniJSON; // For WWW


// 平台SDK接口
public class WebRtcSDK
{
    private bool sdkInited = false;
    public bool SdkInited { get { return sdkInited; } }

    private bool isChating = false;
    public bool IsChating { get { return isChating; } }

    private string chatId = "";
    public string ChatId { get { return chatId; } }

#if UNITY_IPHONE
    // Native 函数声明
    [DllImport("__Internal")]
    private static extern bool rtcInitSDK(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcCreateRoom(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcJoinRoom(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcLeaveRoom(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcSendMsg(string jsonString);
	[DllImport("__Internal")]
	private static extern bool rtcMuteMicrophone(string jsonString);
	[DllImport("__Internal")]
	private static extern bool rtcMuteEarPhone(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcMute(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcMuteSpeaker(string jsonString);
    [DllImport("__Internal")]
    private static extern bool rtcDestroyRoom(string jsonString);
#elif UNITY_ANDROID
    private static AndroidJavaClass webRtcSDK_instance = null;
    public static AndroidJavaClass WebRtcSDK_instance
    {
        get
        {
            if (webRtcSDK_instance == null)
                webRtcSDK_instance = new AndroidJavaClass("com.wow.mutiaudiortc.RtcSdk");
            return webRtcSDK_instance;
        }
    }

    public static AndroidJavaObject sContext;
    public static AndroidJavaObject Context
    {
        get
        {
            if (sContext == null)
            {
                using (AndroidJavaClass cls_UnityPlayer = new AndroidJavaClass("com.unity3d.player.UnityPlayer"))
                {
                    sContext = cls_UnityPlayer.GetStatic<AndroidJavaObject>("currentActivity");
                }
            }
            return sContext;
        }
    }
#endif


    private static WebRtcSDK sInstance = null;
    public static WebRtcSDK Instance
    {
        get
        {
            if (sInstance == null)
                sInstance = new WebRtcSDK();
            return sInstance;
        }
    }

    private main roomView;
    // 初始化SDK
    public bool InitSDK(main view,string host,string port,string[] iceServers)
    {
        roomView = view;

		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("host", host);
		dirt.Add("port", port);
		dirt.Add("iceServers", iceServers);
		string json = Json.Serialize(dirt);
		Debug.Log("InitSDK json = " + json); 
#if UNITY_IPHONE
		return rtcInitSDK(json);
#elif UNITY_ANDROID       
        WebRtcSDK_instance.CallStatic("initSDK", Context, json);
        return true;
#else
        return false;
#endif
    }

    // 创建房间
    public bool CreateRoom(string roomId)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		string json = Json.Serialize(dirt);
		Debug.Log("CreateRoom json = " + json); 
#if UNITY_IPHONE
		return rtcCreateRoom(json);
#elif UNITY_ANDROID       
        WebRtcSDK_instance.CallStatic("createRoom", json);
        return true;
#else
        return false;
#endif
    }

    // 加入房间
    public bool JoinRoom(string roomId)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		string json = Json.Serialize(dirt);
		Debug.Log("JoinRoom json = " + json); 
#if UNITY_IPHONE
		return rtcJoinRoom(json);
#elif UNITY_ANDROID
        
        WebRtcSDK_instance.CallStatic("joinRoom", json);
        return true;
#else
        return false;
#endif
    }

    // 离开房间
    public bool LeaveRoom(string roomId)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		string json = Json.Serialize(dirt);
		Debug.Log("LeaveRoom json = " + json);
#if UNITY_IPHONE
        return rtcLeaveRoom(json);
#elif UNITY_ANDROID
        WebRtcSDK_instance.CallStatic("leaveRoom", json);
        return true;
#else
        return false;
#endif
    }

    // 发送文本消息（暂未实现）
    public bool SendMsg(string roomId, string msg)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		dirt.Add("msg", msg);
		string json = Json.Serialize(dirt);
#if UNITY_IPHONE
		return rtcSendMsg(json);
#elif UNITY_ANDROID
        WebRtcSDK_instance.CallStatic("sendMsg", json);
        return true;
#else
        return false;
#endif
    }

    // 麦克风禁用和解禁(0 or 1)
    public bool MuteMicrophone(string roomId, int setting)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		dirt.Add("mute", setting);
		string json = Json.Serialize(dirt);
#if UNITY_IPHONE
		return rtcMuteMicrophone(json);
#elif UNITY_ANDROID       
        WebRtcSDK_instance.CallStatic("enableLocalMS", json);
        return true;
#else
        return false;
#endif
    }

    // 听筒禁用和解禁(0 or 1)
    public bool MuteEarPhone(string roomId, int setting)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		dirt.Add("mute", setting);
		string json = Json.Serialize(dirt);
#if UNITY_IPHONE
		return  rtcMuteEarPhone(json);
#elif UNITY_ANDROID       
        WebRtcSDK_instance.CallStatic("enableRemoteMS", json);
        return true;
#else
        return false;
#endif
    }

    // 声音禁用和解禁(0 or 1)
    public bool Mute(string roomId, int setting)
    {
        Dictionary<string, object> dirt = new Dictionary<string, object>();
        dirt.Add("room", roomId);
        dirt.Add("mute", setting);
        string json = Json.Serialize(dirt);
#if UNITY_IPHONE_33
		return  rtcMute(json);
#elif UNITY_ANDROID
        WebRtcSDK_instance.CallStatic("mute", json);
        return true;
#else
        return false;
#endif
    }

    // 扬声器禁用和解禁(0 or 1)
    public bool MuteSpeaker(string roomId, int setting)
    {
        Dictionary<string, object> dirt = new Dictionary<string, object>();
        dirt.Add("room", roomId);
        dirt.Add("mute", setting);
        string json = Json.Serialize(dirt);
#if UNITY_IPHONE_33
		return  rtcMuteSpeaker(json);
#elif UNITY_ANDROID
        WebRtcSDK_instance.CallStatic("enableSpeaker", json);
        return true;
#else
        return false;
#endif
    }

    // 销毁房间
    public bool DestroyRoom(string roomId)
    {
		Dictionary<string, object> dirt = new Dictionary<string, object>();
		dirt.Add("room", roomId);
		string json = Json.Serialize(dirt);
#if UNITY_IPHONE
        return rtcDestroyRoom(json);
#elif UNITY_ANDROID
        WebRtcSDK_instance.CallStatic("destroyRoom", json);
        return true;
#else

        return false;
#endif
    }

    #region 回调unity
    public void OnInitSDK(string msg)
    {
        msg = "连接服务器：" + msg;
        if (msg.Equals("false"))
        {
            Debug.LogError("init rtc sdk failed !");
        }
        else
        {
            sdkInited = true;
        }

        roomView.Log(msg);
    }

    public void OnLocalAudioReady(string msg)
    {
        msg = "本地语音流已准备" + msg;
        roomView.Log(msg);
        roomView.ActiveAudio();
    }

    public void OnRtcJoinRoom(string msg)
    {
        msg = "已进入房间,id为：" + msg;
        chatId = msg;
        isChating = true;

        roomView.Log(msg);
    }

    public void OnRtcLeaveRoom(string msg)
    {
        msg += "已离开房间" + msg;

        sdkInited = false;
        isChating = false;
        roomView.Log(msg);
    }
    #endregion
}

