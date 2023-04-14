#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#include "devicetree-parse.h"

/*
struct devicetree_node {
  uint32_t n_properties;
  uint32_t n_children;
  struct devicetree_property *subprops;
  struct devicetree_node *subnodes;
};

struct devicetree_property {
  char name[32];
  uint32_t size;
};

struct phys_range {
  uint64_t phys;
  uint64_t size;
};

struct segment_range {
  uint64_t phys;
  uint64_t virt;
  uint64_t remap;
  uint32_t size;
  uint32_t flags;
};
*/

char* processBytes(const char *arr, int length) {
  char *c = calloc(1, length+1024); // add extra 1024 bytes to avoid read overflow
  char hex[3];
  int ic = 0;
  for (int i = 0; i < length; i++) {
    if (arr[i] == '\\' && arr[i+1] == 'x') {
      hex[0] = tolower(arr[i+2]);
      hex[1] = tolower(arr[i+3]);
      c[ic] = (char)strtol(hex, NULL, 16);
      i+=3;
    } else {
      c[ic] = arr[i];
    }
    ++ic;
  }
  length = ic;
  return (char *)c;
}

char* getPropertyChar(NSDictionary *prop) {
  int prop_length = [prop[@"length"] intValue];
  uint32_t struct_size = 32 + sizeof(uint16_t) * 2;
  uint32_t size = struct_size + (prop_length+0x3 & ~0x3);
  char *result = calloc(1, size);
  strcpy(result, [prop[@"name"] UTF8String]);

  *(uint16_t*)&result[32] = prop_length;
  *(uint16_t*)&result[34] = [prop[@"flags"] intValue];

  if ([prop[@"value"] isKindOfClass:NSNumber.class]) {
    uint64_t value = [prop[@"value"] unsignedLongLongValue];

    switch (prop_length) {
      case 1:
        *((uint8_t *)&result[struct_size]) = value;
        break;
      case 2:
        *((uint16_t *)&result[struct_size]) = value;
        break;
      case 4:
        *((uint32_t *)&result[struct_size]) = value;
        break;
      case 8:
        *((uint64_t *)&result[struct_size]) = value;
        break;
      default:
        printf("Unhandled int size %d\n", prop_length);
        abort();
    }
  } else if ([prop[@"value"] length] > 0) {
    NSString *value = prop[@"value"];
    char *processed = processBytes(value.UTF8String, value.length+1);
    memcpy(&result[struct_size], processed, prop_length);
    free(processed);
  }
  return result;
}

char* getNodeChar(NSArray *node, uint32_t *full_size) {
  uint32_t n_properties = 0;
  uint32_t n_children = 0;
  for (id sub in node) {
    if ([sub isKindOfClass:NSDictionary.class]) {
      ++n_properties;
    } else {
      ++n_children;
    }
  }

  uint32_t size = sizeof(uint32_t) * 2;
  uint32_t current = size;
  uint32_t *properties_size = calloc(sizeof(uint32_t), n_properties);
  char **properties = calloc(sizeof(char *), n_properties);
  uint32_t *child_size = calloc(sizeof(uint32_t), n_children);
  char **child = calloc(sizeof(char *), n_children);

  int iprops = 0, inodes = 0;
  for (id sub in node) {
    if ([sub isKindOfClass:NSDictionary.class]) {
      properties[iprops] = getPropertyChar(sub);
      properties_size[iprops] = 32 + sizeof(uint32_t) + ([sub[@"length"] intValue]+0x3 & ~0x3);
      size += properties_size[iprops];
      //NSLog(@"Prop size %ul", properties_size[iprops]);
      ++iprops;
    } else {
      child[inodes] = getNodeChar(sub, &child_size[inodes]);
      size += child_size[inodes];
      ++inodes;
    }
  }

  if (full_size) {
    *full_size += size;
  }
  char *result = calloc(1, size);
  memcpy(result, &n_properties, sizeof(n_properties));
  memcpy(&result[sizeof(uint32_t)], &n_children, sizeof(n_children));
  for (uint32_t i = 0; i < n_properties; i++) {
    memcpy(&result[current], properties[i], properties_size[i]);
    current += properties_size[i];
  }
  for (uint32_t i = 0; i < n_children; i++) {
    memcpy(&result[current], child[i], child_size[i]);
    current += child_size[i];
  }

  free(properties_size);
  free(properties);
  free(child_size);
  free(child);

  *full_size = size;
  //printf("Result node: %ul, expected: %ul\n", current, size);
  return result;
}

int main(int argc, char **argv) {
  if (argc != 3) {
    printf("Usage: %s <devicetree.json> <output>\n", argv[0]);
    return 1;
  }

  NSString *content = [NSString stringWithContentsOfFile:@(argv[1]) encoding:NSUTF8StringEncoding error:nil];
  NSData *data = [content dataUsingEncoding:NSUTF8StringEncoding];
  NSError *error;
  NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
  if (error) {
    NSLog(@"Error: %@", error);
  }

  FILE *file = fopen(argv[2], "wb");
  if (!file) {
    NSLog(@"Error: %s", strerror(errno));
    return 1;
  }

  uint32_t node_size;
  char *node_str = getNodeChar(dict[@"device-tree"], &node_size);
  fwrite(node_str, node_size, 1, file);
  //printf("fwrite %u\n", node_size);
  fclose(file);
}
