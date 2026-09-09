package com.chengliao.call;

import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.SendTo;
import org.springframework.stereotype.Controller;

/** WebRTC 信令只携带 SDP/ICE，不代理音视频流。客户端仅处理目标 callId。 */
@Controller public class SignalingController {
  @MessageMapping("/calls.signal") @SendTo("/topic/calls") public Signal relay(Signal signal) { return signal; }
  public record Signal(String callId, String from, String to, String kind, Object payload) {} // offer / answer / candidate / hangup
}
