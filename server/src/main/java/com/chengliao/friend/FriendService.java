package com.chengliao.friend;

import java.util.List;
import org.springframework.stereotype.Service;

@Service
public class FriendService {
  private static final String DEFAULT_USER_ID = "u-me";
  private static final String ACCEPTED = "ACCEPTED";

  private final UserFriendRepository repository;

  public FriendService(UserFriendRepository repository) {
    this.repository = repository;
  }

  public List<UserFriend> acceptedFriends(String userId) {
    seedDefaultFriends(userId);
    return repository.findByOwnerIdAndStatusOrderByCreatedAtAsc(userId, ACCEPTED);
  }

  /**
   * The app starts with a small usable contact list.  Only accepted contacts are
   * seeded and returned; requests such as "new friends" deliberately do not
   * appear in this list.
   */
  private void seedDefaultFriends(String userId) {
    if (!DEFAULT_USER_ID.equals(userId) || repository.existsByOwnerIdAndStatus(userId, ACCEPTED)) {
      return;
    }
    repository.saveAll(List.of(
        new UserFriend(userId, "u-deer", "小鹿", "在做项目啦，你呢？"),
        new UserFriend(userId, "u-nana", "娜娜", "哈哈哈，太棒了！"),
        new UserFriend(userId, "u-lin", "林语", "生活需要一点松弛感"),
        new UserFriend(userId, "u-chen", "陈川", "今天也要向前走")));
  }
}
