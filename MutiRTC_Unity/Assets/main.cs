using UnityEngine;
using System.Collections;
using System;
using View;

public class main : MonoBehaviour {

    private readonly float BUTTON_WIDTH = Screen.width * 0.1f;
    private readonly float BUTTON_HEIGHT = Screen.height * 0.05f;

	// Use this for initialization
	void Start () {
	
	}
	
	// Update is called once per frame
	void Update () {
	
	}

    private string mLogString = "";
    private int mLogStringLines = 0;

    private string mRoomId = "";
    private string mMsg = "Hello";

    private bool mMute = false;
    private bool mMPMute = false;           //Microphone开关
    private bool mEPMute = false;           //Earphone开关
    private bool mSpeakerMute = false;      //扬声器开关

    //背景音相关
    private bool mSoundMute = false;
    private float sliderValue;
    private SoundTool.Sound bgSound;

    //信令服务器ip
    public string host = "172.16.130.6";    //改成自己的ip
    //信令服务器端口
    public string port = "3000";            //默认端口
    //ice服务器列表
    public string[] iceServers = { "23.21.150.121", "stun.l.google.com:19302" };

    public void OnGUI()
    {

        float w = BUTTON_WIDTH;
        float h = BUTTON_HEIGHT;
        float x = 2;
        float y = Screen.height * 0.75f;
        float fieldH = 30;

        // Log
        GUI.Label(new Rect(0, 0, Screen.width, y), mLogString.ToString());
        y += 5;


        x = 2;
        GUI.Label(new Rect(x, y, w, h), "RoomId："); x += 100;
        mRoomId = GUI.TextField(new Rect(x, y, 100, fieldH), mRoomId);
        y += fieldH + 5;

        x = 2;
        GUI.Label(new Rect(x, y, w, h), "Message："); x += 100;
        mMsg = GUI.TextField(new Rect(x, y, Screen.width - x - 2, fieldH), mMsg);
        y += fieldH + 5;


        x = 2;
        y = Screen.height - BUTTON_HEIGHT - 5;
        if (GUI.Button(new Rect(x, y, w, h), "Init"))
        {
            Log("Init");
            if (!WebRtcSDK.Instance.SdkInited)
                WebRtcSDK.Instance.InitSDK(this,host, port, iceServers);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), "Join"))
        {
            Log("Join room: " + mRoomId);
            if (!WebRtcSDK.Instance.IsChating)
                WebRtcSDK.Instance.JoinRoom(mRoomId);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), "Leave"))
        {
            Log("Leave room: " + mRoomId);
            WebRtcSDK.Instance.LeaveRoom(mRoomId);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), "SendMsg"))
        {
            Log("Send message to " + mRoomId + " : " + mMsg);
            WebRtcSDK.Instance.SendMsg(mRoomId, mMsg);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), (mMPMute ? "MPMute" : "MPActive")))
        {
            mMPMute = !mMPMute;
            Log("MPMute: " + (mMPMute ? "1" : "0"));
            WebRtcSDK.Instance.MuteMicrophone(mRoomId, mMPMute ? 1 : 0);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), (mEPMute ? "EPMute" : "EPActive")))
        {
            mEPMute = !mEPMute;
            Log("mEPMute: " + (mEPMute ? "1" : "0"));
            WebRtcSDK.Instance.MuteEarPhone(mRoomId, mEPMute ? 1 : 0);
        }
        x += w + 5;

        if (GUI.Button(new Rect(x, y, w, h), (mSpeakerMute ? "SpeakerMute" : "SpeakerActive")))
        {
            mSpeakerMute = !mSpeakerMute;
            Log("mSpeakerMute: " + (mSpeakerMute ? "1" : "0"));
            WebRtcSDK.Instance.MuteSpeaker(mRoomId, mSpeakerMute ? 1 : 0);
        }
        x += w + 5;

        //背景音效
        if (GUI.Button(new Rect(Screen.width - BUTTON_WIDTH, 0, w, h), "PlaySound"))
        {
            Log("PlaySound... ");
            bgSound = SoundTool.Play("test_bgm", 1, 1, 0, true, SoundDef.BGM);
        }
        if (GUI.Button(new Rect(Screen.width - BUTTON_WIDTH, h + 5, w, h), "IsPlaying"))
        {
            bool isPlaying = false;
            if (bgSound != null) { isPlaying = bgSound.IsPlaying(); }
            Log("IsPlaying:" + isPlaying);
        }
        if (GUI.Button(new Rect(Screen.width - BUTTON_WIDTH, 2* h + 5, w, h), "SetVolume"))
        {
            Log("SetVolume... " + sliderValue);
            SoundTool.SetVolume(SoundDef.BGM, sliderValue);
        }

        sliderValue = GUI.HorizontalSlider(new Rect(Screen.width - BUTTON_WIDTH - 200, 2 * h + 20, 200, 50), sliderValue, 0.0f, 1.0f);  
    }

    public void Log(object msg)
    {
        DateTime time = DateTime.Now;
        string message = time.ToString("[HH:mm:ss ffff] ") + msg; // msg for Unicode code

        mLogStringLines++;
        mLogString += message + Environment.NewLine;

        if (mLogStringLines > 40)
        {
            int pos = mLogString.IndexOf(Environment.NewLine + "[");
            if (pos > 0)
            {
                mLogStringLines = 20;
                mLogString = mLogString.Substring(pos + 1);
            }
        }
    }

    public void ActiveAudio()
    {
        mMPMute = true;
        mEPMute = true;  
    }

    void OnApplicationPause(bool isPause)
    {
        if (isPause)
        {
            //Debug.Log("游戏暂停");  // 缩到桌面的时候触发  
            if(Application.platform == RuntimePlatform.Android)
            {
                WebRtcSDK.Instance.Mute(mRoomId, 0);
            }
        }
        else
        {
            //Debug.Log("游戏开始");  //回到游戏的时候触发 最晚  
            if (Application.platform == RuntimePlatform.Android)
            {
                WebRtcSDK.Instance.Mute(mRoomId, 1);
            }
        }
    }

    void OnApplicationFocus(bool isFocus)
    {
        if (isFocus)
        {
                   
        }
        else
        {
           
        }
    }  
}
