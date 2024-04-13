variable "WITH_LATEST_TAG" {
    default = false
}

variable "KALLITHEA_IMAGE_VER" {
    default = "0.7.0"
}

variable "KALLITHEA_PATCH_REV" {
    default = "ed117efc9ae9"
}

variable "KALLITHEA_FLAVOR" {
    default = ["patched-${KALLITHEA_PATCH_REV}", "patched1"]
}

group "default" {
  targets = ["kallithea"]
}

variable "flavor_tags" {
  default = [for f in KALLITHEA_FLAVOR : f == "" ? KALLITHEA_IMAGE_VER : "${KALLITHEA_IMAGE_VER}-${f}"]
}

target "kallithea" {
  context = "./build"
  args = {
    KALLITHEA_VER = "${KALLITHEA_IMAGE_VER}"
    KALLITHEA_REV = "${KALLITHEA_PATCH_REV}"
  }
  platforms = [
    "linux/amd64",
    "linux/arm64",
    "linux/arm/v7",
  ]
  tags = concat(
    formatlist("toras9000/kallithea-mp:%s",             flavor_tags),
    formatlist("ghcr.io/toras9000/docker-kallithea:%s", flavor_tags),
    WITH_LATEST_TAG ? ["toras9000/kallithea-mp:latest", "ghcr.io/toras9000/docker-kallithea:latest"] : []
  )
}
