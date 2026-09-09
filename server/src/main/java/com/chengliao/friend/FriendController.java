package com.chengliao.friend;

import java.util.List;
import org.springframework.web.bind.annotation.CrossOrigin;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Returns only contacts whose friend request has already been accepted. */
@RestController
@RequestMapping("/api/users/{userId}/friends")
@CrossOrigin(originPatterns = "*")
public class FriendController {
  private final FriendService friendService;

  public FriendController(FriendService friendService) {
    this.friendService = friendService;
  }

  @GetMapping
  public List<FriendResponse> list(@PathVariable String userId) {
    return friendService.acceptedFriends(userId).stream()
        .map(friend -> new FriendResponse(
            friend.friendId,
            friend.displayName,
            friend.signature,
            friend.avatarUrl,
            friend.status))
        .toList();
  }

  public record FriendResponse(
      String id,
      String displayName,
      String signature,
      String avatarUrl,
      String status) {
  }
}
