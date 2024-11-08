local oyuncu  = require("kutuphane.oyuncu")
local Veri    = require("kutuphane.veri")
local renkli  = require("kutuphane.ansicolors")
local inspect = require("kutuphane.inspect")
local Ag      = require("kutuphane.ag")
local Dunya   = require("kutuphane.dunya")
local bildir  = require("kutuphane.bildirim")
local konsol  = require("kutuphane.konsol")

local VARSAYILAN =
{
    ADRES = "127.0.0.1:6161",
}

local istemci = { tip = "Istemci" }

-- eger bir tabloda bir fonksiyon veya deger bulunamassa
-- o tablonun metatablosunun __index degiskenindeki 
-- fonksiyon cagrilir. eger __index degiskeni fonksiyon yerine
-- tablo ise bu tabloda bu deger aranır. burada bu durum kullanıldı
istemci.__index = istemci
istemci.__newindex = YENI_INDEKS_UYARISI

function istemci:yeni(o)
    o = o or {}

    o.adres                        = o.adres or VARSAYILAN.ADRES
    o.oyuncu                       = o.oyuncu or oyuncu:yeni({ oyuncu_tip = oyuncu.ISTEMCI })
    o.ag                           = Ag({adres = o.adres, tip = "Istemci"})
    o.dunya                        = Dunya()
    o.istatistik                   = {}
    o.istatistik.gonderilen_paket  = 0
    o.istatistik.alinan_paket      = 0
    o.durum                        = "Hazırlanıyor"
    sinyal_fonksiyon_bagla("Konsol.yazi_girildi", function (yazi)
        if yazi:find("/") ~= 1 then
            o.ag:yayinla("Sunucu/sohbet", Veri():string_ekle(yazi))
            return true
        end
        return false
    end)

    setmetatable(o, self)

    return o
end

-- istemci tablosunun istemci:yeni(...) seklinde cagrilmasi
-- yerine istemci(...) seklinde cagrilabilmesini saglar
setmetatable(istemci, { __call = istemci.yeni })

function istemci:__tostring()
    return renkli("%{yellow}<Istemci> [\n%{reset}" .. inspect.inspect(self) .. "\n%{yellow}]")
end

local function oyuncu_guncelle(hedef, tablo, baslangic_indeks, yoksay)
    local id = tablo[baslangic_indeks]
    local hx = tablo[baslangic_indeks + 1]
    local hy = tablo[baslangic_indeks + 2]
    local x  = tablo[baslangic_indeks + 3]
    local y  = tablo[baslangic_indeks + 4]

    if id == yoksay then
        return baslangic_indeks + 5
    end

    if hedef[id] == nil then
        hedef[id] = oyuncu:yeni {
            oyuncu_tip = oyuncu.ISTEMCI
        }
    end

    hedef[id].hareket_vektor.x = hx
    hedef[id].hareket_vektor.y = hy
    hedef[id].yer.x = x
    hedef[id].yer.y = y

    return baslangic_indeks + 5
end

function istemci:mesaj_isle(mesaj)
    if mesaj == nil then
        return
    end

    local _, mesaj_turu = string.match(mesaj[MESAJ_KANAL_TUR_ALANI], "(%a+)/(.+)")

    if mesaj_turu == "durum_guncelle" then
        local oyuncu_sayisi = mesaj[MESAJ_TIP_OZEL_1]
        local idx = MESAJ_TIP_OZEL_2
        for _ = 1, oyuncu_sayisi do
            idx = oyuncu_guncelle(self.dunya.oyuncular, mesaj, idx, self.ag.id)
        end

    elseif mesaj_turu == "id_al" then
        local id = mesaj[MESAJ_TIP_OZEL_1]
        self.ag.id = id
        self.ag:ayarla_kimlik(tostring(id))
        self.ag:abone_ol(self.ag:getir_kimlik())
        self.ag:abonelik_iptal("Lobi")
        self.durum = "Hazır"
        bildir.bilgi("ID alındı: " .. tostring(id))
    elseif mesaj_turu == "oyuncu_ekle" then
        local id = mesaj[MESAJ_TIP_OZEL_1]
        local isim = mesaj[MESAJ_TIP_OZEL_2]

        if id ~= self.ag.id then
            self.dunya:oyuncu_ekle(id, oyuncu({isim = isim, oyuncu_tip = oyuncu.ISTEMCI}))
        else
            self.dunya:oyuncu_ekle(id, oyuncu({isim = isim, oyuncu_tip = oyuncu.NORMAL}))
        end
    elseif mesaj_turu == "sohbet" then
        if self.ag.id == mesaj[MESAJ_TIP_OZEL_3] then
            konsol.metin:metine_yazi_ekle("[Sen]", mesaj[MESAJ_TIP_OZEL_2])
        else
            konsol.metin:metine_yazi_ekle(mesaj[MESAJ_TIP_OZEL_1], mesaj[MESAJ_TIP_OZEL_2])
            konsol.metin.zamanlayici:yeniden_kur()
        end
    end
end

function istemci:durum_bildirimi_yap()
    local ben = self:getir_benim_oyuncum()
    local durum = Veri():i32_ekle(self.ag.id)
                        :bayt_ekle(ben.hareket_vektor.x)
                        :bayt_ekle(ben.hareket_vektor.y)
                        :f32_ekle(ben.yer.x)
                        :f32_ekle(ben.yer.y)

    self.ag:yayinla("Sunucu/oyuncu_durum_guncelle", durum)
end

function istemci:ag_islemleri()
    local olay = self.ag.kapi:service()
    while olay do
        if olay.type == "receive" then
            self.istatistik.alinan_paket = self.istatistik.alinan_paket + 1
            local mesaj = self.ag:filtrele(olay.data)
            self:mesaj_isle(mesaj)
        elseif olay.type == "connect" then
            -- id elde etme islemi
            local veri = Veri():string_ekle(self.ag:getir_kimlik()):string_ekle(self.oyuncu.isim)
            self.ag:yayinla("Lobi/id_al", veri)
        elseif olay.type == "disconnect" then
        end
        olay = self.ag.kapi:service()
    end
end

function istemci:varliklari_guncelle(dt)
    for _, varlik in pairs(self.sunucu_varliklar) do
        varlik:guncelle(dt)
    end
end

function istemci:varliklari_ciz()
    for _, varlik in pairs(self.sunucu_varliklar) do
        varlik:ciz()
    end
end

function istemci:guncelle(dt)
    self:ag_islemleri()

    if self.durum == "Hazır" then
        self.dunya:guncelle(dt)
        self:durum_bildirimi_yap()
    elseif self.durum == "Hazırlanıyor" then
        bildir.uyari("Bağlanılıyor...")
    end
end

function istemci:ciz()
    if self.durum == "Hazır" then
        self.dunya:ciz()
    end
end

function istemci:getir_benim_oyuncum()
    return self.dunya:getir_oyuncu(self.ag.id)
end

return istemci
