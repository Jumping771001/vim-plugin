"       Filename: sms.vim
"       Description: sms code and decode
"       Author: Jumping
"       Version: 01
"       
"key map {{{       
"\pd     decode current line pdu sms
nmap <leader>pd :call SMS_PduDecode()<CR>
"\pen  encode normal pdu sms  the phone nomube store register a
nmap <leader>pen :call SMS_PduEncode("<C-R>a") <CR>
"\pec  encode class0 pdu sms  the phone nomube store register a
nmap <leader>pec :call SMS_PduEncode("<C-R>a",1) <CR>
"\pes encode sms with head   the user data head store in regiset b
nmap <leader>pes :call SMS_PduEncode("<C-R>a",strlen("<C-R>b")/2,"<C-R>b") <CR>
"}}}

"local variable {{{
"ucs2 -> gbk dictonary
let s:isThereCHinese = 0
let s:ucs2gbk = {}
let s:gbk2ucs = {}
let s:path = expand("<sfile>:p:h")."/"
let s:h2b = {"0":"0000", "1": "0001","2": "0010","3": "0011","4": "0100","5": "0101","6": "0110","7": "0111",
            \"8":"1000", "9": "1001","A": "1010","B": "1011","C": "1100","D": "1101","E": "1110","F": "1111"}
let s:b2h = {"0000":"0", "0001":"1", "0010":"2", "0011":"3", "0100":"4", "0101":"5", "0110":"6", "0111":"7",
            \"1000":"8", "1001":"9", "1010":"A", "1011":"B", "1100":"C", "1101":"D", "1110":"E", "1111":"F"}
"}}}

"SMS_7BitTo8Bit {{{1
function! s:SMS_7BitTo8Bit(str7bit,offset)
    let bitByte = ""
    let temp = ""
    let str8bit = ""

    "倒排7bit2进制字串 
    let i = 0
    while i< strlen(a:str7bit)
        let bitByte = s:h2b[a:str7bit[i]].s:h2b[a:str7bit[i+1]].bitByte
        if i == 0
            if a:offset > 0
                " 如果是连接短信，短线内容不是紧接着短信头，而是短信头经过7Bit对齐后的位置
                let bitByte = strpart(bitByte,0,8-a:offset)
            endif
        endif
        let i += 2
    endwhile
"     exe "normal o".bitByte
    "顺排8bit2进制字串
    let i = strlen(bitByte)-1
    while i > 5
        let temp = temp.'0'.bitByte[i-6].bitByte[i-5].bitByte[i-4].bitByte[i-3].bitByte[i-2].bitByte[i-1].bitByte[i]
        let i -= 7
    endwhile
"     exe "normal o".temp

    "转换陈16进制字串
    let i = 0
    while i< strlen(temp)
        let str8bit .= s:b2h[strpart(temp,i,4)]
        let i += 4
    endwhile

"     exe "normal o".str8bit
    return str8bit
endfunction
"}}}1

"SMS_PduDecode {{{1
function! SMS_PduDecode ()
    let currentStr = getline(".")
    let currentIdx = 0

    "read sca 
    let scaLen = strpart(currentStr,currentIdx,2)
    let currentIdx += 2
    if 0 != scaLen
        let scaType = strpart(currentStr,currentIdx,2)
        let currentIdx = currentIdx + 2
        let scaAddr = s:SMS_Isdn2Noraml(strpart(currentStr,currentIdx,("0x".scaLen-1)*2))
        let currentIdx += ("0x".scaLen-1)*2
        let scaPre = ""
        if scaType == "91"
            let scaPre = "+"
        endif
        exe "normal o"."短信中心:".scaPre.scaAddr
        "echo scaPre.scaAddr
    endif

    "read pdu type
    let pduType = "0x".strpart(currentStr,currentIdx,2) + 0
    let currentIdx = currentIdx + 2
    "echo pduType

    let pduRp = pduType/128
    let pduUdhi = pduType/64 - pduRp*2
    let pduMti = pduType - (pduType/4)*4

    if pduMti == 0
        echo "deliver sms"
        let pduSri = pduType/32 - pduUdhi*2 - pduRp*4
        let pduMms = pduType/4 - (pduType/8)*2

        "read OA
        let oaLen = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2
        let oaType = strpart(currentStr,currentIdx,2)
        let currentIdx += 2
        let oaAddr = s:SMS_Isdn2Noraml(strpart(currentStr,currentIdx,((oaLen+1)/2)*2))
        let currentIdx += ((oaLen+1)/2)*2
        let oaPre = ""
        if oaType == "91"
            let oaPre = "+"
        endif
        exe "normal o"."发送方号码:".oaPre.oaAddr
        "echo oaPre.oaAddr
    elseif pduMti == 1
        let pduSrr = pduType/32 - pduUdhi*2 - pduRp*4
        let pduVpf = pduType/8 - pduSrr*4 - pduUdhi*8 - pduRp*16
        let pduRd = pduType/4 - (pduType/8)*2
        echo "submit sms"

        "read MR
        let mr = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx = currentIdx + 2

        "read OA
        let daLen = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2
        let daType = strpart(currentStr,currentIdx,2)
        let currentIdx += 2
        let daAddr = s:SMS_Isdn2Noraml(strpart(currentStr,currentIdx,((daLen+1)/2)*2))
        let currentIdx += ((daLen+1)/2)*2
        let daPre = ""
        if daType == "91"
            let daPre = "+"
        endif
        exe "normal o"."接受方号码:".daPre.daAddr
        "echo daPre.daAddr

    elseif pduMti == 2
        echo "report sms"
        "read MR
        let mr = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx = currentIdx + 2
        
        "read RA
        let raLen = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2
        let raType = strpart(currentStr,currentIdx,2)
        let currentIdx += 2
        let raAddr = s:SMS_Isdn2Noraml(strpart(currentStr,currentIdx,((raLen+1)/2)*2))
        let currentIdx += ((raLen+1)/2)*2
        let raPre = ""
        if raType == "91"
            let raPre = "+"
        endif
        exe "normal o"."报告方号码:".raPre.raAddr
    endif

    if pduMti != 2

        "read PID
        let pid = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2

        "read dcs
        let dcs = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2
        "echo dcs
        let dcs_bit32 = dcs/4 - (dcs/16)*4 
        exe "normal oDCS:".dcs
        "echo dcs_bit32
    endif

    if pduMti == 0
        "read scts
        let scts= strpart(currentStr,currentIdx,2*7)
        let currentIdx += 2*7
        exe "normal o"."短信中心时间戳:".scts[1].scts[0]."-".scts[3].scts[2]."-".scts[5].scts[4]." ".scts[7].scts[6].":".scts[9].scts[8].":".scts[11].scts[10]."+".scts[13].scts[12]
        "echo scts[1].scts[0]."-".scts[3].scts[2]."-".scts[5].scts[4]." ".scts[7].scts[6].":".scts[9].scts[8].":".scts[11].scts[10]."+".scts[13].scts[12]
    elseif pduMti == 1
        " read VP
        if pduVpf == 2
            let vp = "0x".strpart(currentStr,currentIdx,2) + 0
            let currentIdx += 2
            if vp < 0x8f
                exe "normal o" . "短信有效期:" . (vp + 1)*5 . "分钟"
            elseif vp < 0xa7
                exe "normal o" . "短信有效期:" . ((vp -143)*30 + 12*60) . "分钟"
            elseif vp < 0xa7
                exe "normal o" . "短信有效期:" . (vp - 166) . "天"
            else
                exe "normal o" . "短信有效期:" . (vp - 192) . "周"
            endif
        elseif pduVpf == 3
            let scts= strpart(currentStr,currentIdx,2*7)
            let currentIdx += 2*7
            exe "normal o"."短信有效期:".scts[1].scts[0]."-".scts[3].scts[2]."-".scts[5].scts[4]." ".scts[7].scts[6].":".scts[9].scts[8].":".scts[11].scts[10]."+".scts[13].scts[12]
        endif

    elseif pduMti == 2
        let scts= strpart(currentStr,currentIdx,2*7)
        let currentIdx += 2*7
        exe "normal o"."短信中心时间戳:".scts[1].scts[0]."-".scts[3].scts[2]."-".scts[5].scts[4]." ".scts[7].scts[6].":".scts[9].scts[8].":".scts[11].scts[10]."+".scts[13].scts[12]
        let dt= strpart(currentStr,currentIdx,2*7)
        let currentIdx += 2*7
        exe "normal o"."发短信时间:".dt[1].dt[0]."-".dt[3].dt[2]."-".dt[5].dt[4]." ".dt[7].dt[6].":".dt[9].dt[8].":".dt[11].dt[10]."+".dt[13].dt[12]
        let st= strpart(currentStr,currentIdx,2)
        let currentIdx += 2
        if st == 0
            exe "normal o" . "状态: 对方成功接收" 
        elseif st == 1
            exe "normal o" . "状态: 短信中心已经转发，但还没得到确认" 
        elseif st == 2
            exe "normal o" . "状态: 短信被放回" 
        else
            exe "normal o" . "状态: " . st  
        endif
    endif

    if pduMti != 2
        "read UDL
        let udl = "0x".strpart(currentStr,currentIdx,2) + 0
        let currentIdx += 2

        "read UD
        if pduUdhi == 1  
            let udhLen = "0x".strpart(currentStr,currentIdx,2) + 0
            let currentIdx += 2
            let udhData = strpart(currentStr,currentIdx,udhLen*2)
            let currentIdx += udhLen*2
            exe "normal o"."短信头:".udhData
            let ud = strpart(currentStr,currentIdx,(udl-udhLen-1)*2)
        else
            let ud = strpart(currentStr,currentIdx,udl*2)
        endif


        exe "normal o"."短信正文:".ud
        "echo ud 

        "2个字节一个字符
        if dcs_bit32 == 2 
            "双字节
            let ud = s:SMS_ucs2gbk(ud)
            let byte = 2
        elseif dcs_bit32 ==0 
            "7个bit为一个字符
            if pduUdhi == 1
                let offset = ((udhLen+1)*8+7)/7*7-(udhLen+1)*8
            else
                let offset = 0
            endif
            let ud = s:SMS_7BitTo8Bit(ud,offset)
            let byte = 1
        else
            "单字节
            let byte = 1
        endif

        exe "normal o转换后正文:".ud 

        let udBin = s:SMS_Str2bin(ud,byte)
        exe "normal o".udBin
        "call s:SMS_7BitTo8Bit(ud)
    endif

endfunction
"}}}

"SMS_Isdn2Noraml {{{1
function! s:SMS_Isdn2Noraml(isdnStr)
    let i = 0
    let norStr = ""
    while i < strlen(a:isdnStr) 
        let norStr = norStr.a:isdnStr[i+1]
        if a:isdnStr[i] != "F"
            let norStr = norStr.a:isdnStr[i]
        endif
        let i += 2
    endwhile
    return norStr
endfunction
"}}}1

"SMS_Normal2Isdn {{{
function! s:SMS_Normal2Isdn(NorStr)
    let Isdn = ""
    let norStr = ""
    let len = strlen(a:NorStr) 

    if len%2 != 0
        let norStr .= a:NorStr .'F'
    else
        let norStr .= a:NorStr
    endif


    let i = 0
    while i < strlen(norStr) 
        let Isdn .= norStr[i+1]
        let Isdn .= norStr[i]
        let i += 2
    endwhile

    return Isdn
endfunction
"}}}

"SMS_Str2bin {{{
function! s:SMS_Str2bin(str,byte)
    let bin = ""
    let i = 0
    let offset = a:byte*2
    while i < strlen(a:str)
        let bin .= nr2char("0x".strpart(a:str,i,offset))
        let i += offset 
    endwhile
    return bin 
endfunction
"}}}
    
"SMS_ucs2gbk {{{
function! s:SMS_ucs2gbk(ucs)
    let gbk = ""
    let i = 1
    "create dictionary of ucs to gbk
    if empty(s:ucs2gbk)
        "convert ascii
        while i<128 
            let index = printf("%04X",i)
            let s:ucs2gbk[index] = printf("%02X",i)
            let i += 1
        endwhile
        "convert chinese
        let u2g = readfile(s:path."ucs2gbk.dat")
        for u2gLine in u2g 
            let ug = split(u2gLine)
            let s:ucs2gbk[ug[0]] = ug[1]
        endfor
    endif
    "call writefile(values(s:ucs2gbk),"temp.dat")
    "conver string
    
    let i = 0
    while i < strlen(a:ucs)
        let gbk .= s:ucs2gbk[strpart(a:ucs,i,4)]
        let i += 4 
    endwhile
    return gbk 
endfunction
"}}}

"SMS_gbk2ucs {{{
function! s:SMS_gbk2ucs(gbk)
    let ucs = ""
    let i = 1
    if empty(s:gbk2ucs)
        while i<128
            let index = printf("%02X",i)
            let s:gbk2ucs[index] = printf("%04X",i)
            let i+=1
        endwhile
        let g2u = readfile(s:path."ucs2gbk.dat")
        for g2uLine in g2u
            let gu = split(g2uLine)
            let s:gbk2ucs[gu[1]] = gu[0]
        endfor
    endif

    let i = 0
    while i < strlen(a:gbk)
        if char2nr(a:gbk[i]) > 0x80
            let s:isThereCHinese = 1
            echo a:gbk[i]
            break
        endif
        let i += 1
    endwhile
    let i = 0
    while i < strlen(a:gbk)
        let gbkItem = printf("%02X",char2nr(strpart(a:gbk,i,1)))
        if "0x".gbkItem > 0x80
            let i += 1
            let gbkItem .= printf("%02X", char2nr(strpart(a:gbk, i, 1))) 
        endif
        "echo gbkItem
        if s:isThereCHinese == 1
            let ucs.= s:gbk2ucs[gbkItem]
        else
            let ucs.= gbkItem
        endif

        let i += 1
    endwhile
    
    return ucs
endfunction
"}}}

"SMS_PduEncode {{{
"SMS_PduEncode("13801666119",UDHL,UDHC)  发送带短信头的短信 UDHL:短信头长度 UDHC:短信头内容
"SMS_PduEncode("13801666119")  发送普通短信
"SMS_PduEncode("13801666119",1) 发送CLASS0短信

function! SMS_PduEncode(number,...)
    let currentStr       = getline(".")
    "let currentStr      = getreg('0')
    let s:isThereCHinese = 0
    let ucsContent       = s:SMS_gbk2ucs(currentStr)
    let SCA              = "00"

    let PT_RP   = "0"
    let PT_UDHI = "0"
    let PT_SRR  = "0"
    let PT_VPF  = "10"
    let PT_RD   = "0"
    let PT_MTI  = "01"

    let MR  = "00"
    let DA  = s:SMS_Normal2Isdn(a:number)
    let DA  = printf("%02X",strlen(a:number)) ."81" .DA
    let PID = "00"

    let DCS_76 = "00"
    let DCS_5  = "0"
    let DCS_4  = "0"

    if s:isThereCHinese == 1
        let DCS_32 = "10"
    else
        let DCS_32 = "01"
    endif

    let DCS_10 = "00"

    " 二个参数是calss0短信类型
    if a:0 == 1
        if a:1 ==1
            let DCS_4  = "1"
        else
            let DCS_10 = "01"
        endif
    endif

    let DCS    = DCS_76.DCS_5.DCS_4.DCS_32.DCS_10
    let DCS    = s:b2h[strpart(DCS,0,4)].s:b2h[strpart(DCS,4,4)]

    "3个参数是否有短信头
    let UDHL       = 0
    let UDHContent = ""
    if a:0 == 2
        let PT_UDHI = "1"
        let UDHL = a:1
        if UDHL != (strlen(a:2)/2)
            exe "normal o UDHL input is error!"
            let UDHL = strlen(a:2)/2
        endif
        let UDHContent = a:2
    endif

    let VP      = "FF"
    let PDUType = PT_RP.PT_UDHI.PT_SRR.PT_VPF.PT_RD.PT_MTI
    let PDUType = s:b2h[strpart(PDUType,0,4)].s:b2h[strpart(PDUType,4,4)]
    let UDL     = printf("%02X", strlen(ucsContent)/2+UDHL+1)
    if 0 == UDHL
        exe "normal oat+cmgs=".(strlen(ucsContent)/2+6+strlen(DA)/2)
        exe "normal o".SCA.PDUType.MR.DA.PID.DCS.VP.UDL.ucsContent
    else
        exe "normal oat+cmgs=".(strlen(ucsContent)/2+UDHL+7+strlen(DA)/2)
        exe "normal o".SCA.PDUType.MR.DA.PID.DCS.VP.UDL.printf("%02X",UDHL).UDHContent.ucsContent
    endif
endfunction
"}}}

command! -nargs=1 U2G echo s:SMS_Str2bin(s:SMS_ucs2gbk(<f-args>))
map <leader>ug y:U2G <c-r>0<cr>
command! -nargs=1 C728 echo s:SMS_7BitTo8Bit(<f-args>)
" vim: fdm=marker
