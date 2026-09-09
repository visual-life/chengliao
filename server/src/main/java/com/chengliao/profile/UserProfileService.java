package com.chengliao.profile;

import java.time.Instant;
import org.springframework.stereotype.Service;

@Service
public class UserProfileService {
  private static final String DEFAULT_USER_ID = "u-me";
  private static final String DEFAULT_DISPLAY_NAME = "晨曦";
  private static final String DEFAULT_SIGNATURE = "保持热爱，奔赴山海。";

  private final UserProfileRepository repository;

  public UserProfileService(UserProfileRepository repository) {
    this.repository = repository;
  }

  public UserProfile getOrCreate(String userId) {
    return repository.findById(userId)
        .orElseGet(() -> repository.save(defaultProfile(userId)));
  }

  public UserProfile updateProfile(String userId, String signature, String avatarUrl) {
    UserProfile profile = getOrCreate(userId);
    profile.signature = signature;
    if (avatarUrl != null) {
      profile.avatarUrl = avatarUrl;
    }
    profile.updatedAt = Instant.now();
    return repository.save(profile);
  }

  private UserProfile defaultProfile(String userId) {
    if (DEFAULT_USER_ID.equals(userId)) {
      return new UserProfile(DEFAULT_USER_ID, DEFAULT_DISPLAY_NAME, DEFAULT_SIGNATURE);
    }
    return new UserProfile(userId, userId, "");
  }
}
