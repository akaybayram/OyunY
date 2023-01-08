local inspect = require("inspect")
local Veri    = require("veri")
local Ag      = require("ag")
local oyuncu  = require("oyuncu")
local renkli  = require("ansicolors")
local Dunya   = require("dunya")
require("genel")
-- TODO: sunucuya versiyon kontrolü ekle

local Sunucu = { tip = "Sunucu" }
Sunucu.__index = Sunucu
Sunucu.__newindex = YENI_INDEKS_UYARISI

function Sunucu:yeni(o)
    o = o or {}

    o.adres         = o.adres or "*:6161"
    o.ag            = Ag({adres = o.adres, tip = "Sunucu"})
    o.dunya         = 0
    o.hazirlanan_id = 1

    setmetatable(o, self)
    o.dunya         = Dunya()

    o:ekrana_yaz("Sunucu basladi! Havagi :)")

    return o
end

function Sunucu:__tostring()
    return renkli("%{yellow}<Sunucu>\n[%{reset}\n" .. inspect.inspect(self) .. "\n%{yellow}] %{reset}")
end

setmetatable(Sunucu, { __call = Sunucu.yeni })

function Sunucu:kapat()
  self.ag.kapi:destroy()
end

function Sunucu:getir_bagli_oyuncu_sayisi()
  return self.ag.kapi.peer_count()
end

function Sunucu:ekrana_yaz(yazi)
  print(renkli("%{green}[ " .. tostring(math.ceil(love.timer.getTime() * 1000)) .. " ]%{reset} " .. yazi))
end

function Sunucu:mesaj_isle(mesaj)
    if mesaj == nil then
        return
    end

    local _, mesaj_turu = string.match(mesaj[1], "(%a+)/(.+)")
    local hedef_konu = mesaj[2]
    local isim = mesaj[3]
    if mesaj_turu == "id_al" then
        self.ag.yayinci:yayinla(hedef_konu .. "/id_al", Veri():i32_ekle(self.hazirlanan_id))
        self:oyuncu_ekle(self.hazirlanan_id, oyuncu({isim = isim, oyuncu_tip = oyuncu.SUNUCU}))
        self.hazirlanan_id = self.hazirlanan_id + 1
    end
end

function Sunucu:oyuncu_cikar(olay)
  local adam_kayip = true
  for i, oy in pairs(self.oyuncular) do
    if olay.peer == oy.kanal then
      table.remove(self.oyuncular, i)
	  self.nesne_sayisi = self.nesne_sayisi - 1
      self:ekrana_yaz("Adam kesildi " .. inspect.inspect(olay))
      adam_kayip = false
    end
  end

  if adam_kayip then
    self:ekrana_yaz("Adam kayip Rıza baba :)")
  end
end

function Sunucu:olay_isle(olay)
    if olay.type == "connect" then
    elseif olay.type == "receive" then
        self:mesaj_isle(self.ag.abone:filtrele(olay.data))
    elseif olay.type == "disconnect" then
    end
end

function Sunucu:guncelle(dt)
    local olay = self.ag.kapi:service()
    while olay do
        self:olay_isle(olay)
        olay = self.ag.kapi:service()
    end
    self.dunya:guncelle(dt)
end

function Sunucu:oyuncu_ekle(id, oy)
    self.dunya:oyuncu_ekle(id, oy)
    self:ekrana_yaz("Oyuncu baglandi.")
end

return Sunucu
