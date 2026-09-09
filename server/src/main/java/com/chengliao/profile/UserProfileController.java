package com.chengliao.profile;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Profile endpoints used by the personal-signature editor. */
@RestController
@RequestMapping("/api/users/{userId}/profile")
@CrossOrigin(originPatterns = "*")
public class UserProfileController {
  private final UserProfileService profileService;

  public UserProfileController(UserProfileService profileService) {
    this.profileService = profileService;
  }

  @GetMapping
  public UserProfile get(@PathVariable String userId) {
    return profileService.getOrCreate(userId);
  }

  @PutMapping
  public UserProfile update(
      @PathVariable String userId,
      @Valid @RequestBody UpdateProfileRequest request) {
    return profileService.updateProfile(userId, request.signature(), request.avatarUrl());
  }

  public record UpdateProfileRequest(
      @NotNull @Size(max = 120) String signature,
      @Size(max = 512) String avatarUrl) {
  }
}
