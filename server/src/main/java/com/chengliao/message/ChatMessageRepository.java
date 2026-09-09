package com.chengliao.message;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface ChatMessageRepository extends JpaRepository<ChatMessage,String> { List<ChatMessage> findByConversationIdOrderByCreatedAtDesc(String conversationId, Pageable pageable); }
