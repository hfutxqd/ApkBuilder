# Apk编译脚本

无需gradle和ant，只需要Android SDK（NDK）即可一键编译apk   

## 使用步骤
1. 配置环境变量ANDROID_HOME和ANDROID_NDK_ROOT，分别指向Android SDK的根目录和Android NDK根目录
2. 安装cmake，把cmake添加到环境变量PATH中
3. 安装python2.7
4. 使用使用以下命令安装ConfigParser    
`python2.7 -m pip install ConfigParser`
5. 按照示例编写apk_builder.properties项目配置文件
6. 使用apk_builder.sh脚本编译项目，执行./apk_builder.sh [path to project root]

## 功能说明
支持AIDL    
支持Kotlin    
支持基于cmake的ndk编译    
支持zip align优化    
支持v1和v2签名    
    
暂不支持多dex    

## 其他说明
测试环境：    
macOS 10.14.1    
Android SDK build tool 28.0.3    
Kotlin 1.3.10    
cmake 3.12.3