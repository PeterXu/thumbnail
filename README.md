Thumbnail media service
===================


## 1. Config nginx
##### a. config nginx(liblua5.1-0/lua-cjson)
compile nginx with lua support(lua-nginx-module)
```
aptitude install nginx-full
mv /usr/sbin/nginx /usr/sbin/nginx.old

apt-get install liblua5.1-0 lua-cjson
cp nginx_with_lua /usr/sbin/nginx       # nginx_with_lua is your compiled binary
cp ngx_thumb.conf /etc/nginx/sites-enabled/
```

##### b. config the privilege of nginx user(www-data) in /etc/sudoers
```
www-data ALL=(ALL) NOPASSWD:/bin/mv
```


## 2. Config lua 
##### a. set lua script/logo(replace your logo.png)
```
mkdir /usr/local/thumb
cp thumb_video.lua /usr/local/thumb/
cp logo.png /usr/local/thumb/  # logo should be exist
```

##### b. config the 'src/dst' path in thumb_video.lua
```
local spath = "/home/image/src"
local dpath = "/home/image/dst"
```
Nginx user(www-data default) must have read privileges in 'spath' and write in 'dpath'.


## 3. Install ffmpeg and reload nginx
compile the latest ffmpeg with version 3.0+.
```
cp ffmpeg_v3 /usr/local/bin/ffmpeg
sudo service nginx restart
```


## 4. usage
***HTTP POST with json*** (POST /api/v1/thumb):
```
{"src":"test.mp4", "dst":"test.jpg"}
```
It will generate thumbnail("/home/image/dst/test.jpg") of the video("/home/image/src/test.mp4")
from default timeoffset of "00:00:15", with the same width/height as original video.

```
{"src":"test.mp4", "dst":"test.jpg", "width":320}
```
It will generate thumbnail of width-320 with the same aspect ration as original video (height is computed).

```
{"src":"test.mp4", "dst":"test.jpg", "height":240, "timeoff":"00:00:30"}
```
It will generate thumbnail of height-240 with the same aspect ration as original video (width is computed).
from time offset of "00:00:30".


***Basic Format***: 
```
a. 'src/dst' required,  
b. 'width/height/timeoff' optional,  
c. 'dst' filename must have valid image extension, e.g. '.jpg'/'.png'/'.bmp',  
d. 'timeoff' is '00:00:15' default("HH:MM:SS", hour/minute/second), from the 15th second of video.  
e. if one of 'width/height' or both is not exist, will refer to the video's aspect ratio.  
```


***The response code***:
```
200 - OK and return response json: {'data':'the dst url'}.
400 - Bad Requst: the format of json is invalid.
403 - Fobidden: The 'dst' file has been exist in 'dpath' and cannot be override.
404 - Not Found: (a) The 'src' file is not exist in 'spath'; (b) The logo is not exist.
405 - Invalid method, only support HTTP POST.
406 - Not Acceptable: (a) no 'src/dst' in json; (b) no valid ext(image type) in the 'dst' filename.
417 - Expectation Failed: ffmpeg running error.
```

