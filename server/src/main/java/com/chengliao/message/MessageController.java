package com.chengliao.message;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.data.domain.PageRequest;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController @RequestMapping("/api/conversations/{conversationId}/messages") @CrossOrigin(originPatterns="*")
public class MessageController {
  private final ChatMessageRepository repository; private final SimpMessagingTemplate broker;
  public MessageController(ChatMessageRepository repository, SimpMessagingTemplate broker) { this.repository=repository; this.broker=broker; }
  @GetMapping public List<ChatMessage> history(@PathVariable String conversationId, @RequestParam(defaultValue="50") int limit) { var list=repository.findByConversationIdOrderByCreatedAtDesc(conversationId, PageRequest.of(0, Math.min(limit,100))); Collections.reverse(list); return list; }
  @PostMapping public ChatMessage send(@PathVariable String conversationId, @Valid @RequestBody SendMessage body) {
    var m=new ChatMessage(); m.conversationId=conversationId; m.senderId=body.senderId(); m.type=body.type()==null?"text":body.type(); m.content=body.content(); m.mediaUrl=body.mediaUrl(); m.durationMs=body.durationMs();
    m=repository.save(m); broker.convertAndSend("/topic/conversations/"+conversationId, m); return m;
  }
  public record SendMessage(@NotBlank String senderId, String type, String content, String mediaUrl, Integer durationMs) {}
}
