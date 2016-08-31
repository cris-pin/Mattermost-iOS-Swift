#!/bin/bash

KEYCHAIN_PATH=.travis/travis.keychain

security list-keychains -s "$KEYCHAIN_PATH"
security default-keychain -s "$KEYCHAIN_PATH"
security unlock-keychain -p $MATCH_PASSWORD "$KEYCHAIN_PATH"

