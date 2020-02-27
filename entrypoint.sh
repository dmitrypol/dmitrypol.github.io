#!/bin/bash
# https://docs.docker.com/config/containers/multi-service_container/
set -m

#   https://zarino.co.uk/post/jekyll-local-network/
bundle exec jekyll server --drafts --host 0.0.0.0

# while :
# do
# 	echo "Press [CTRL+C] to stop.."
# 	sleep 1
# done

fg %1