# UnityRTC
基于webrtc的unity多人游戏实时语音(A Unity Demo for Impl Real-time Game Voice Among Mutiplayers Based On WEBRTC)
## 简介
### MutiRTC_Unity
  unity工程，基于版本5.3.3f1。包含一个简单的多人实时语音聊天室场景。语音模块以平台sdk形式集成进unity，包括安卓和ios的语音sdk，详见plugins目录。<br>
  可支持多人视频(videotrack)和文字聊天(datachannel)，暂时屏蔽了
#### 支持功能：
* 多人同时在线聊天：由于基于webrtc的p2p连接，每两个人之间都有一个peerconnection，只能少数几人互通，否则性能会有问题
* 支持android和ios
* 语音扬声器模式与游戏背景音共存
* 语音断线重连
### SignalServer
  信令服务器，即房间服务器，负责端对端信令的传输。
  基于 https://github.com/LingyuCoder/SkyRTC-demo ，主要修改了：
* candidate传输的字段，适应ios的显示
* 增加了服务端心跳。websocket不能响应客户端突然断网的情况，onclose回调不到。通过心跳来判断和移除断开连接的peer
### ICE Server
  ICE Server 用来实现p2p穿墙或可靠传输。
  基于 https://github.com/coturn/coturn ，具体环境的搭建参考网上资料。如果只是测试，可以用第三方的服务器，比如：http://numb.viagenie.ca/ 可以申请账号，demo中有提供申请好的账号，如果是局域网同一wifi，不需要ice server
## 使用
### MutiRTC_Unity
* Main Camera 上的Main脚本中修改Host/Port为自己的信令服务器ip地址和端口，IceServers修改为自己搭建或申请的stun/turn地址
* 打包app，先init，再输入房间号join
---
  各按钮功能：
* init：初始化sdk，与信令服务器建立连接
* join：加入指定房间
* leave：离开房间，结束会话
* sendmsg：暂未实现
* mpactive：麦克风开关，控制己方说话
* epactive：听筒开关，控制接收对方说话
* speakeractive：扬声器开关
* playsound：播放背景音乐
* setvolume：调节背景音量
---
  iOS打包注意事项：
* ios的语音库太大没有上传，从 http://pan.baidu.com/s/1o7UyI4U 下载libwebrtc.a库，拷贝至目录：Plugins\IOS\AudioRtc\libjingle_peerconnection\
* 导出工程到xcode，build settings中找到bitcode enable设为NO（因为该版本libwebrtc.a未支持bitcode）
* build phases 中link binary with libraries添加依赖库：libicucore.tbd，GLKit.framework，VideoToolbox.framework，Security.framework，CoreTelephony.framework
* ios应用工程可参考 https://github.com/tuyaohui/WebRTC_iOS
### SignalServer
  安装nodejs环境，modules都已上传，无需再install，cd至SignalServer目录，命令行执行 node server.js
