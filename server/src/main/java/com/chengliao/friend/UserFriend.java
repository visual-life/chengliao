package com.chengliao.friend;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;

/** A confirmed relationship in a user's friend list. */
@Entity
@Table(
    name = "user_friends",
    indexes = @Index(name = "idx_user_friend_status", columnList = "ownerId,status"))
public class UserFriend {
  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  public String id;

  @Column(nullable = false, length = 80)
  public String ownerId;

  @Column(nullable = false, length = 80)
  public String friendId;

  @Column(nullable = false, length = 20)
  public String status = "ACCEPTED";

  @Column(nullable = false, length = 80)
  public String displayName;

  @Column(nullable = false, length = 120)
  public String signature = "";

  @Column(length = 500)
  public String avatarUrl;

  @Column(nullable = false)
  public Instant createdAt = Instant.now();

  protected UserFriend() {
    // Required by JPA.
  }

  public UserFriend(String ownerId, String friendId, String displayName, String signature) {
    this.ownerId = ownerId;
    this.friendId = friendId;
    this.displayName = displayName;
    this.signature = signature;
  }
}
