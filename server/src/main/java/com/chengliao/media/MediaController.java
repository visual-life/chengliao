package com.chengliao.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException; import java.nio.file.*; import java.util.*;

@RestController @RequestMapping("/api/media") @CrossOrigin(originPatterns="*")
public class MediaController {
  private final Path root;
  public MediaController(@Value("${chat.upload-dir}") String uploadDir) throws IOException { root=Paths.get(uploadDir).toAbsolutePath().normalize(); Files.createDirectories(root); }
  @PostMapping(consumes=MediaType.MULTIPART_FORM_DATA_VALUE) public Map<String,String> upload(@RequestPart MultipartFile file) throws IOException {
    if(file.isEmpty()) throw new IllegalArgumentException("文件不能为空");
    var ext=StringUtils.getFilenameExtension(file.getOriginalFilename()); var name=UUID.randomUUID()+(ext==null?"":"."+ext.toLowerCase(Locale.ROOT)); Files.copy(file.getInputStream(), root.resolve(name), StandardCopyOption.REPLACE_EXISTING);
    return Map.of("url", "/api/media/"+name, "name", Objects.requireNonNullElse(file.getOriginalFilename(),name));
  }
  @GetMapping("/{name:.+}") public ResponseEntity<org.springframework.core.io.Resource> get(@PathVariable String name) throws IOException { var resource=new org.springframework.core.io.UrlResource(root.resolve(name).toUri()); return ResponseEntity.ok().contentType(MediaTypeFactory.getMediaType(resource).orElse(MediaType.APPLICATION_OCTET_STREAM)).body(resource); }
}
