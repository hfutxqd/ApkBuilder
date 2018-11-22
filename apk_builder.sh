#!/usr/bin/env bash

CPATH=`pwd`
export PATH="$CPATH:$PATH"

export PROJ=$1

if [[ ! -e $ANDROID_HOME ]]; then
    echo "ANDROID_HOME must be set"
    exit -1
fi

if [[ ! -e $ANDROID_NDK_ROOT ]]; then
    echo "ANDROID_NDK_ROOT must be set"
    exit -1
fi

echo "ANDROID_HOME is set to "${ANDROID_HOME}
echo "ANDROID_NDK_ROOT is set to "${ANDROID_NDK_ROOT}

export BUILD_TOOL_PATH=${ANDROID_HOME}"build-tools/"
cd $PROJ

export buildToolVersion=`get_prop.py Build buildToolVersion`
export compileSdkVersion=`get_prop.py Build compileSdkVersion`
export resourceDir=`get_prop.py Build resourceDir`
export srcDir=`get_prop.py Build srcDir`
export libsDir=`get_prop.py Build libsDir`
export buildJni=`get_prop.py Build buildJni`
export kotlinc=`get_prop.py Build kotlinc`

export BUILD_TOOL_PATH=${BUILD_TOOL_PATH}${buildToolVersion}
export AAPT=${BUILD_TOOL_PATH}"/aapt"
export AIDL=${BUILD_TOOL_PATH}"/aidl"
export DX=${BUILD_TOOL_PATH}"/dx"
export ZIPALIGN=${BUILD_TOOL_PATH}"/zipalign"
export APKSIGNER=${BUILD_TOOL_PATH}"/apksigner"
export PLATFORM=${ANDROID_HOME}"/platforms/android-"${compileSdkVersion}"/android.jar"
export AIDL_FRAMEWORK=${ANDROID_HOME}"/platforms/android-"${compileSdkVersion}"/framework.aidl"

echo "Cleaning..."
rm -rf build/*
if [[ ! -f "sourceFileList.txt" ]]; then
    rm -rf sourceFileList.txt
fi
if [[ ! -f "aidlFileList.txt" ]]; then
    rm -rf aidlFileList.txt
fi

echo "PreBuilding..."
${AAPT} package -f -m -J ${PROJ}/${srcDir} -M ${PROJ}/${srcDir}/AndroidManifest.xml -S ${PROJ}/${resourceDir} -I ${PLATFORM}
find ${PROJ}/${srcDir} -type f -name '*.aidl' > aidlFileList.txt
for line in `cat aidlFileList.txt`
do
    ${AIDL} -p${AIDL_FRAMEWORK} ${line}
done


echo "start build ..."
if [[ ! -d "build/" ]];then
    mkdir build
fi

if [[ ! -d "build/obj" ]];then
    mkdir build/obj
fi

if [[ ! -d "build/bin" ]];then
    mkdir build/bin
fi

if [[ "${buildJni}" == "true" ]]; then
echo "Building jni..."

    # https://cmake.org/cmake/help/v3.12/manual/cmake-toolchains.7.html#cross-compiling-for-android-with-the-ndk
    ARCH_ABI=`get_prop.py NDK archAbi`
    if [[ ! -e $ARCH_ABI ]]; then
        ARCH_ABI="armeabi-v7a";
    fi
    API_LEVEL=`get_prop.py NDK apiLevel`
    if [[ ! -e $API_LEVEL ]]; then
        API_LEVEL=21;
    fi
    cmake ${PROJ} \
      -B${PROJ}/build/jni \
      -DCMAKE_SYSTEM_NAME=Android \
      -DCMAKE_SYSTEM_VERSION=${API_LEVEL} \
      -DCMAKE_ANDROID_ARCH_ABI=${ARCH_ABI} \
      -DCMAKE_ANDROID_NDK=${ANDROID_NDK_ROOT} \
      -DCMAKE_LIBRARY_OUTPUT_DIRECTORY=${PROJ}/build/jni/lib/${ARCH_ABI} \
      -DCMAKE_ANDROID_STL_TYPE=gnustl_static

    cd ${PROJ}/build/jni
    make
    cd ${PROJ}

fi

# Build classes
echo "Building classes..."

# build java
find ${PROJ}/${srcDir} -type f -name '*.java' > sourceFileList.txt
javac -d build/obj -source 1.7 -target 1.7 -classpath ${PROJ}/${srcDir}:${PROJ}/${libsDir}/* -bootclasspath ${PLATFORM} @sourceFileList.txt

# build kotlin
if [[ -e ${kotlinc} ]]; then
    echo "Building kotlin..."
    find ${PROJ}/${srcDir} -type f -name '*.kt' > sourceFileList.txt
    ${kotlinc} -cp build/obj:${PROJ}/${libsDir}:${PLATFORM} @sourceFileList.txt -d build/obj/
fi

# Build dex
if [[ ! -n "ls ${PROJ}/${libsDir}/*.jar" ]]; then
    echo "Building dex without libs..."
    ${DX} --dex --output=${PROJ}/build/bin/classes.dex ${PROJ}/build/obj
else
    echo "Building dex with libs..."
    ${DX} --dex --output=${PROJ}/build/bin/classes.dex ${PROJ}/${libsDir}/*.jar ${PROJ}/build/obj
fi


# Package apk
cd ${PROJ}
echo "Packaging apk..."
${AAPT} package -f -m -F ${PROJ}/build/bin/app.apk -M ${PROJ}/${srcDir}/AndroidManifest.xml -S ${PROJ}/${resourceDir} -I ${PLATFORM}
cd build/bin
${AAPT} add ${PROJ}/build/bin/app.apk classes.dex
cd ${PROJ}/build/jni
${AAPT} add ${PROJ}/build/bin/app.apk lib/*/*

# Zip align apk
echo "Zip aligning apk..."
${ZIPALIGN} -f 4 ${PROJ}/build/bin/app.apk ${PROJ}/build/bin/app_aligned.apk

# Sign apk
cd ${PROJ}
useSignerV2=`get_prop.py Sign useSignerV2`
storepass=`get_prop.py Sign storepass`
keypass=`get_prop.py Sign keypass`
keyalias=`get_prop.py Sign keyalias`
keystore=`get_prop.py Sign keystore`

echo "Signing apk with SignerV1..."
jarsigner -keystore ${keystore} -storepass ${storepass} -keypass ${keypass} ${PROJ}/build/bin/app_aligned.apk ${keyalias} -signedjar ${PROJ}/build/bin/app_signedV1.apk
if [[ "${useSignerV2}" == "true" ]]; then
    echo "Signing apk with SignerV2..."
    echo ${keypass}|${APKSIGNER} sign  --ks ${keystore} --out ${PROJ}/build/bin/app_signedV2.apk ${PROJ}/build/bin/app_signedV1.apk
fi

echo "Success. Apk file is at ${PROJ}/build/bin/app_signedV2.apk"