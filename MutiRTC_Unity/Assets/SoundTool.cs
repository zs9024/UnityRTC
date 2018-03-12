
using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace View
{
    public enum SoundDef
    {
        EtM, //音效
        BGM, //背景音乐
    }

    public class SoundTool : MonoBehaviour
    {

        static private SoundTool instance = null;
        static private SoundTool Instance
        {
            get
            {
                if (instance == null)
                {
                    instance = Camera.main.gameObject.AddComponent<SoundTool>();
                }
                return instance;
            }
        }

        private AudioListener mListener;
        private List<Sound> mActiveList = new List<Sound>();
        private List<Sound> mCachesList = new List<Sound>();
        private int index;

        private static float EtMVolume = 1f;
        private static float BGMVolume = 1f;

        public float GetVolume(SoundDef def)
        {
            if (def == SoundDef.EtM)
            {
                return EtMVolume;
            }
            else
            {
                return BGMVolume;
            }
        }

        public class Sound
        {
            public AudioClip clip;
            public AudioSource source;
            public SoundDef def;
            public float volume;
            public float pitch;
            public bool isLoop;

            public Sound(AudioSource _source)
            {
                source = _source;
            }

            public void Play(float scale)
            {
                source.clip = clip;
                source.pitch = pitch;
                source.volume = volume * scale;
                source.loop = isLoop;
                source.Play();
            }

            public bool IsPlaying()
            {
                return source.isPlaying;
            }

            public IEnumerator PlayDelay(float scale, float delay)
            {
                yield return new WaitForSeconds(delay);
                Play(scale);
            }

            public void Stop()
            {
                if (clip != null)
                {
                    Resources.UnloadAsset(clip);
                    clip = null;
                    source.clip = null;
                }
                source.gameObject.SetActive(false);
            }

            public void SetVolume(float _volume)
            {
                source.volume = volume * _volume;
            }
        }

        void Update()
        {
            for (int i = 0; i < mActiveList.Count; ++i)
            {
                Sound node = mActiveList[i];
                if (!node.isLoop && !node.IsPlaying())
                {
                    Remove(node);
                    break;
                }
            }
        }

        private void Init()
        {
            if (mListener == null || !mListener.gameObject.activeSelf)
            {
                AudioListener[] listeners = GameObject.FindObjectsOfType(typeof(AudioListener)) as AudioListener[];

                if (listeners != null)
                {
                    for (int i = 0; i < listeners.Length; ++i)
                    {
                        if (listeners[i].gameObject.activeSelf)
                        {
                            mListener = listeners[i];
                            break;
                        }
                    }
                }

                if (mListener == null)
                {
                    Camera cam = Camera.main;
                    if (cam == null) cam = GameObject.FindObjectOfType(typeof(Camera)) as Camera;
                    if (cam != null) mListener = cam.gameObject.AddComponent<AudioListener>();
                }

                AudioSource source = mListener.GetComponent<AudioSource>();
                if (source == null)
                    mListener.gameObject.AddComponent<AudioSource>();
            }
        }

        private Sound Get(string key)
        {
            if (mCachesList.Count > 0)
            {
                Sound sound = mCachesList[mCachesList.Count - 1];
                sound.source.gameObject.SetActive(false);
                mActiveList.Add(sound);
                mCachesList.RemoveAt(mCachesList.Count - 1);
                return sound;
            }
            else
            {
                GameObject obj = new GameObject("Source" + index++);
                obj.transform.SetParent(transform);
                AudioSource source = obj.AddComponent<AudioSource>();
                Sound sound = new Sound(source);
                mActiveList.Add(sound);
                return sound;
            }
        }

        private Sound _Play(string name, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            return this._Play(name, 1f, 1f, 0f, isLoop, def);
        }

        private Sound _Play(string name, float volume, float pitch, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            return this._Play(name, volume, pitch, 0f, isLoop, def);
        }

        private Sound _Play(string name, float volume, float pitch, float delay, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            Init();
            
            Sound sound = Get(name);
            sound.clip = Resources.Load<AudioClip>(name);
            sound.volume = volume;
            sound.pitch = pitch;
            sound.isLoop = isLoop;
            sound.def = def;

            if (delay > 0)
            {
                StartCoroutine(sound.PlayDelay(GetVolume(def), delay));
            }
            else
            {
                sound.Play(GetVolume(def));
            }
           return sound;

        }

        private void _Clear()
        {
            for (int i = 0; i < mActiveList.Count; ++i)
            {
                Sound node = mActiveList[i];
                node.Stop();
                mCachesList.Add(node);
            }
            mActiveList.Clear();
        }

        private void _SetVolume(SoundDef def, float volume)
        {
            if (def == SoundDef.EtM)
                EtMVolume = volume;
            else
                BGMVolume = volume;

            for (int i = 0; i < mActiveList.Count; ++i)
            {
                Sound node = mActiveList[i];
                if (node.def == def)
                    node.SetVolume(volume);
            }
        }

        private void _Remove(Sound sound)
        {
            if (mActiveList.Contains(sound))
            {
                sound.Stop();
                mCachesList.Add(sound);
                mActiveList.Remove(sound);
            }
        }

        public static Sound Play(string name, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            return Instance._Play(name, isLoop, def);
        }

        public static Sound Play(string name, float volume, float pitch, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            return Instance._Play(name, volume, pitch, isLoop, def);
        }

        public static Sound Play(string name, float volume, float pitch, float delay, bool isLoop = false, SoundDef def = SoundDef.EtM)
        {
            return Instance._Play(name, volume, pitch, delay, isLoop, def);
        }

        public static Sound Play(int id)
        {
//             if (id == 0)
//                 return null;
// 
//             Config.Sound.Entry soundBcc = (Config.Sound.Entry)DataCenter.Instance.GetEntry(BCCType.Sound, id);
// 
//             if (soundBcc != null && !string.IsNullOrEmpty(soundBcc.Name))
//             {
//                 if (soundBcc.Type == 0)
//                     return Play(soundBcc.Name, soundBcc.Volume, soundBcc.Pitch, soundBcc.IsLoop > 0, SoundDef.EtM);
//                 else
//                     return Play(soundBcc.Name, soundBcc.Volume, soundBcc.Pitch, soundBcc.IsLoop > 0, SoundDef.BGM);
//             }
            return null;
        }

        public static Sound PlayInConfig(string key)
        {
//             Config.Config.Entry soundEntry = (Config.Config.Entry)Config.DataCenter.Instance.GetEntry(BCCType.Config, key);
//             if (soundEntry != null)
//                 return SoundTool.Play(soundEntry.Value);
//             else
//                 return null;
            return null;
        }

        public static void Remove(Sound sound)
        {
            Instance._Remove(sound);
        }

        public static void Clear()
        {
            Instance._Clear();
        }

        public static void SetVolume(SoundDef def, float volume)
        {
            Instance._SetVolume(def, volume);
        }
    }

}

