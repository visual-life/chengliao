package com.chengliao.friend;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserFriendRepository extends JpaRepository<UserFriend, String> {
  boolean existsByOwnerIdAndStatus(String ownerId, String status);

  List<UserFriend> findByOwnerIdAndStatusOrderByCreatedAtAsc(String ownerId, String status);
}
