#!/bin/sh -ex

frameworks="libswiftCore libswiftCoreGraphics libswiftCoreImage libswiftDarwin libswiftDispatch libswiftFoundation libswiftObjectiveC libswiftUIKit libswiftContacts"

for framework in $frameworks
do

install_name_tool -change "@rpath/${framework}.dylib" "@loader_path/Frameworks/${framework}.dylib" ${BUILT_PRODUCTS_DIR}/${EXECUTABLE_PATH}

done
