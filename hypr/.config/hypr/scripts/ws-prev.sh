#!/bin/bash

cur="$(hyprctl activeworkspace -j | jq '.id')"

hyprctl dispatch workspace "$(((cur - 2 + 5) % 5 + 1))"
