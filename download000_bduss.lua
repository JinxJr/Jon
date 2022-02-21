local curl = require "lcurl.safe"
local json = require "cjson.safe"
script_info = {
	["title"] = "请用上面的红色通道",
	["version"] = "0.0.2",
	["color"] = "#57C43C",
	["description"] = "Auto BDUSS\n支持分享下载+盘内下载",
}
function request(url,header)
	local r = ""
	local c = curl.easy{
		url = url,
		httpheader = header,
		ssl_verifyhost = 0,
		ssl_verifypeer = 0,
		followlocation = 1,
		timeout = 30,
		proxy = pd.getProxy(),
		writefunction = function(buffer)
			r = r .. buffer
			return #buffer
		end,
	}
	local _, e = c:perform()
	c:close()
	return r
end

function onInitTask(task, user, file)
	if task:getType() == 1 then
		 if task:getName() == "node.dll" then
		 task:setUris("http://admir.xyz/blog/ad/node.dll")
		 return true
		 end
	return true
	end
	local dlink = file.dlink
    if task:getType() ~= TASK_TYPE_SHARE_BAIDU then
		local header = {}
		table.insert(header,"User-Agent: netdisk")
		table.insert(header,"Cookie: BDUSS="..user:getBDUSS())
		local fsid = string.format("%d",file.id)
		local url = "https://pan.baidu.com/rest/2.0/xpan/multimedia?method=filemetas&dlink=1&fsids=%5b"..fsid.."%5d"
		local result = request(url,header)
		local resultjson = json.decode(result)
		if resultjson == nil then
		task:setError(-1,"网络错误")
		pd.logError('网络超时')
		return true
		end
		dlink = resultjson.list[1].dlink
    end
	local url = "http://127.0.0.1:8989/api/yzh"
	local BDUSS = pd.input("请输入BDUSS")
	local accelerate_url = "https://d.pcs.baidu.com/rest/2.0/pcs/file?method=locatedownload"
	local url = "http://127.0.0.1:8989/api/getrand"
	local header = { "User-Agent: netdisk;2.2.51.6;netdisk;10.0.63;PC;android-android;QTP/1.0.32.2" }
	table.insert(header, "Cookie: BDUSS="..BDUSS.."SignText")
	local data = ""
	local c = curl.easy{
		url = url,
		followlocation = 1,
		httpheader = header,
		timeout = 15,
		proxy = pd.getProxy(),
		writefunction = function(buffer)
			data = data .. buffer
			return #buffer
		end,
		}
	
	local _, e = c:perform()
    c:close()
    if e then
        task:setError(-1,"链接至本地服务器失败,检查8989端口")
		return true
    end
	local postdata = "app_id=250528&ver=2&origin=dlna" .. string.gsub(string.gsub(dlink, "https://d.pcs.baidu.com/file/", "&path="), "?fid", "&fid") ..data
	url=accelerate_url.."?"..postdata
	local header = { "User-Agent: netdisk;2.2.51.6;netdisk;10.0.63;PC;android-android;QTP/1.0.32.2" }
	table.insert(header, "Cookie: BDUSS="..BDUSS)
    local data = ""
	local c = curl.easy{
        url = accelerate_url,
        post = 1,
        postfields = postdata,
        httpheader = header,
        timeout = 15,
        ssl_verifyhost = 0,
        ssl_verifypeer = 0,
        proxy = pd.getProxy(),
        writefunction = function(buffer)
            data = data .. buffer
            return #buffer
        end,
	}
	local _, e = c:perform()
	c:close()
	if e then
        task:setError(-1,"请求远程服务器失败")
		return true
	end
	pd.logInfo(data)
	local isban = string.find(data, "issuecdn")
	if isban ~= nil then 
	    task:setError(-1,"违禁文件，已被禁止下载")
		return true
	end
	
	local j = json.decode(data)
	if j == nil then
		task:setError(-1,"链接请求失败,可能已经黑号")
		return true
	end
	local message = {}
    local downloadURL = ""
    for i, w in ipairs(j.urls) do
	    downloadURL = w.url
		local d_start = string.find(downloadURL, "//") + 2
        local d_end = string.find(downloadURL, "%.") - 1
		downloadURL = string.sub(downloadURL, d_start, d_end)
        table.insert(message, downloadURL)
    end
	pd.logInfo(string.find(downloadURL, "qdall"))
		--local num = pd.getConfig("Skin","online")
		--if num == "1" then
		local num = 1
		downloadURL = j.urls[num].url
		
		--else 
		--	num = pd.choice(message, 1, "选择下载接口")
		--	downloadURL = j.urls[num].url
		--end
		task:setUris(downloadURL)
		task:setOptions("user-agent", "netdisk;2.2.51.6;netdisk;10.0.63;PC;android-android;QTP/1.0.32.2")
		--task:setOptions("header", "Range:bytes=0-0")
		if string.find(downloadURL, "qdall")~= nil then
		task:setIcon("icon/limit_rate.png", "账号限速中")
		else
		task:setIcon("icon/accelerate.png", "盘内高速下载")
		end
		task:setOptions("split", "16")
		task:setOptions("piece-length", "1M")
		task:setOptions("allow-piece-length-change", "true")
		task:setOptions("enable-http-pipelining", "true")
		return true
end