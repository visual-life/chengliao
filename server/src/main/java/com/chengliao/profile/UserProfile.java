package com.chengliao.profile;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

/** A small, persistent profile record used by the desktop client's "Me" area. */
@Entity
@Table(name = "user_profiles")
public class UserProfile {
  @Id
  @Column(name = "user_id", nullable = false, length = 80)
  public String userId;

  @Column(nullable = false, length = 80)
  public String displayName;

  @Column(nullable = false, length = 120)
  public String signature = "";

  @Column(length = 512)
  public String avatarUrl;

  @Column(nullable = false)
  public Instant updatedAt = Instant.now();

  protected UserProfile() {
    // Required by JPA.
  }

  public UserProfile(String userId, String displayName, String signature) {
    this.userId = userId;
    this.displayName = displayName;
    this.signature = signature;
  }
}
