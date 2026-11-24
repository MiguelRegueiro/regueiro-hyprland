#!/bin/bash

cur="$(hyprctl activeworkspace -j | jq '.id')"

hyprctl dispatch workspace "$((cur % 5 + 1))"
