#!/bin/bash
set -xeou pipefail
export LC_COLLATE=C

trap 'echo "FAIL >>> please put device back into usb mode and rerun script to continue"' ERR

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <dump_name>"
  exit 1
fi

timestamp=$(date +%Y%m%d%H%M%S)
dump_name=$1
dump_dir_name=dump-"$1"

mem_addr=0x1080000
chunk_size=0x4000000
total_size=3959422976

mkdir -p out

if [[ -d ./"$dump_dir_name" ]]; then
  last_file=$(ls -v ./"$dump_dir_name" | tail -n 1)
  if [[ -n "$last_file" ]]; then
    start_mib=$(echo "$last_file" | cut -d'-' -f3 | tr -d "MiB")
    start_offset=$((start_mib * 1024 * 1024))
    rm -f "./$dump_dir_name/$last_file"
  else
    start_offset=0
  fi
else
  mkdir ./"$dump_dir_name"
  start_offset=0
fi

./update write ./superbird.bl2.encrypted.bin 0xfffa0000
./update run 0xfffa0000
sleep 3

./update bl2_boot ./superbird.bootloader.img
sleep 5

./update bulkcmd "mmc dev 1"
./update bulkcmd "amlmmc key"
sleep 1

for ((offset_bytes = start_offset; offset_bytes < total_size; offset_bytes += chunk_size)); do
  chunk_num=$(printf "%03d" $((offset_bytes / chunk_size)))
  hex_offset=$(printf "0x%x" $((offset_bytes / 512)))
  hex_chunk_size=$(printf "0x%x" $chunk_size)
  hex_chunk_size_blocks=$(printf "0x%x" $((chunk_size / 512)))
  start_mib=$((offset_bytes / (1024 * 1024)))
  end_mib=$(((offset_bytes + chunk_size) / (1024 * 1024)))

  ./update bulkcmd "mmc read $mem_addr $hex_offset $hex_chunk_size_blocks"
  sleep 5
  ./update mread mem $mem_addr normal "$hex_chunk_size" "$dump_dir_name"/"$chunk_num"-chunk-${start_mib}MiB-${end_mib}MiB.bin

  if [ "$chunk_num" == "002" ]; then
    cat "$dump_dir_name"/000-chunk-*.bin "$dump_dir_name"/001-chunk-*.bin >./out/"$dump_name"-first-172MiB-"$timestamp".bin
    head -c $((44 * 1024 * 1024)) "$dump_dir_name"/002-chunk-*.bin >>./out/"$dump_name"-first-172MiB-"$timestamp".bin
  fi
done

cat "$dump_dir_name"/*.bin >./out/"$dump_name"-full-emmc-"$timestamp".bin

rm -rf ./"$dump_dir_name"
echo "dumped!"
