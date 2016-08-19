-- HTTP POST with json, which support the following formats:
--      a. {"src":"test.mp4", "dst":"test.jpg", "width":640, "height":320, "timeoff":"00:00:15"}
--      b. {"src":"test.mp4", "dst":"test.jpg", "width":640, "timeoff":"00:00:15"}
--      c. {"src":"test.mp4", "dst":"test.jpg", "height":320}
--      d. {"src":"test.mp4", "dst":"test.jpg"}
-- The 'src'/'dst' required, and 'width'/'height'/'timeoff' is optional.
-- The 'src' file should be exist in 'spath'(see below),


-- 3rd modules
local cjson = require("cjson.safe") 

-- config global parameters
local spath = "/home/image/src"
local dpath = "/home/image/dst"
local rapi = "" -- e.g, http://thumb.host/api/v1
local logo = "/usr/local/thumb/logo.png"
local default_timeoff = "00:00:15"

-- ffmpeg parameters
local ropt1 = "-an -f image2 -r 1 -vframes 1"
local ropt2 = "-vf \"movie="..logo.." [watermark]; [in][watermark] overlay=W/2-w/2:H/2-h/2 [out]\""


-- check file whether exist or not
function fexists(n)
    local f = io.open(n)
    if (f) then
        io.close(f)
        return true
    end
    return false
end

-- get filename's extension name
function getext(str)
    return str:match(".+%.(%w+)$")
end

-- generate thumbnail
function func_thumb(src, dst, width, height, timeoff)
    -- check args
    if (not(src and dst)) then
        return 406, nil -- not acceptable
    end
    if (not timeoff) then
        return 406, nil -- not acceptable
    end

    -- src/dst file
    src = spath .. "/" .. src
    dst = dpath .. "/" .. dst

    -- check input/output file
    if (not fexists(src)) then
        return 404, nil -- not found
    end
    if (fexists(dst)) then
        return 403, nil -- fobidden
    end
    local ext = getext(dst)
    if (not ext) then
        return 406, nil  -- not acceptable
    end

    local ret = 1
    local msg = nil
    local icode = 200

    -- shell cmd
    local tmp = string.format("/tmp/thumb_%d.%s", os.time(), ext)
    local tmp2 = string.format("/tmp/thumb_%d_02.%s", os.time(), ext)
    local cmd1 = string.format("ret=0; src=%s; tmp=%s; tmp2=%s; dst=%s;", src, tmp, tmp2, dst)
    local cmd2
    if (width and height) then
        cmd2 = string.format(
        "ffmpeg -ss %s -i $src %s -s %dx%d -y $tmp >/dev/null 2>&1 || exit 1;",
        timeoff, ropt1, width, height)
    else if (not width and not height) then
        cmd2 = string.format(
        "ffmpeg -ss %s -i $src %s -y $tmp >/dev/null 2>&1 || exit 1;", 
        timeoff, ropt1)
    else if (not height) then
        cmd2 = string.format(
        "ffmpeg -ss %s -i $src %s -vf \"scale=%d:trunc(ow/a/2)*2\" -y $tmp >/dev/null 2>&1 || exit 1;", 
        timeoff, ropt1, width)
    else if (not width) then
        cmd2 = string.format(
        "ffmpeg -ss %s -i $src %s -vf \"scale=oh*a:trunc(%d/2)*2\" -y $tmp >/dev/null 2>&1 || exit 1;", 
        timeoff, ropt1, height)
    end
    end
    end
    end
    local cmd3 = string.format("ffmpeg -i $tmp %s -y $tmp2;", ropt2)
    local cmd4 = "sudo /bin/mv $tmp2 $dst || ret=2; rm -f $tmp $tmp2; exit $ret"

    -- shell run
    local cmd = cmd1 .. cmd2 .. cmd3 .. cmd4
    ret = os.execute(cmd)
    -- ngx.say(cmd.."<br>")
    if (ret > 0) then
        icode = 417 -- expectation failed
    else
        local uri, num = string.gsub(dst, dpath.."/", "")
        msg = rapi..uri
    end

    return icode, msg
end


--------------
-- main entry
--------------

local code = 405
local msg = nil
local src, dst, width, height, timeoff


-- check logo
if (not fexists(logo)) then
    return 404, nil -- not found
end


-- check method
local method = ngx.req.get_method()
if (method == "GET") then
    local uri_args = ngx.req.get_uri_args()
    src   = uri_args["src"]
    dst   = uri_args["dst"]
    width = uri_args["width"]
    width = uri_args["height"]
else if (method == "POST") then
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    local json = cjson.decode(data);
    if (not json) then
        return ngx.exit(400)
    end

    -- require
    src = json["src"]
    dst = json["dst"]

    -- option
    width = json["width"]
    height = json["height"]
    timeoff = json["timeoff"]

    if (not timeoff) then
        timeoff = default_timeoff
    end

    code, msg = func_thumb(src, dst, width, height, timeoff)
    if (code == 200) then
        local jdata = string.format("{\"data\":[\"%s\"]}", msg);
        ngx.header["content-length"] = string.len(jdata)
        ngx.print(jdata)
    end
end
end

return ngx.exit(code)
