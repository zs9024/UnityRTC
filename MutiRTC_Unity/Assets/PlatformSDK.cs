using UnityEngine;


public class PlatformSDK : MonoBehaviour {

    private static PlatformSDK instance = null;
    public static PlatformSDK Instance
    {
        get
        {
            if (instance == null)
            {
                GameObject main = GameObject.Find("PlatformSDK");
                if (main == null)
                {
                    main = new GameObject("PlatformSDK");
                }
                instance = main.GetComponent<PlatformSDK>();
                if (instance == null)
                {
                    instance = main.AddComponent<PlatformSDK>();
                }
            }
            return instance;
        }
    }

    #region 实时语音
    void OnRtcInitSdk(string msg)
    {
        Debug.Log("PlatformSDK OnRtcInitSdk msg : " + msg);
        WebRtcSDK.Instance.OnInitSDK(msg);
    }

    void OnLocalAudioReady(string msg)
    {
        Debug.Log("PlatformSDK OnLocalAudioReady msg : " + msg);
        WebRtcSDK.Instance.OnLocalAudioReady(msg);
    }

    void OnRtcJoinRoom(string msg)
    {
        Debug.Log("PlatformSDK OnRtcJoinRoom msg : " + msg);
        WebRtcSDK.Instance.OnRtcJoinRoom(msg);
    }

    void OnRtcLeaveRoom(string msg)
    {
        Debug.Log("PlatformSDK OnRtcLeaveRoom msg : " + msg);
        WebRtcSDK.Instance.OnRtcLeaveRoom(msg);
    }
    #endregion
}
