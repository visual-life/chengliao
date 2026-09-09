package com.chengliao.message;

import jakarta.persistence.*;
import java.time.Instant;

@Entity @Table(name="chat_messages", indexes = @Index(name="idx_conversation_created", columnList="conversationId,createdAt"))
public class ChatMessage {
  @Id @GeneratedValue(strategy=GenerationType.UUID) public String id;
  @Column(nullable=false, length=80) public String conversationId;
  @Column(nullable=false, length=80) public String senderId;
  @Column(nullable=false, length=20) public String type = "text"; // text/image/audio/file
  @Column(columnDefinition="TEXT") public String content;
  @Column(length=500) public String mediaUrl;
  public Integer durationMs;
  @Column(nullable=false) public Instant createdAt = Instant.now();
}
