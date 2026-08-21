--[[ ==========================================================================

    BU DOSYA SADECE REFERANSTIR - DUZENLEMEYIN.

    Anti-cheat bu dosyayi OKUMAZ. Ayarlariniz her zaman config.lua
    dosyasindadir; burasi yalnizca guncel ayar listesini ve aciklamalarini
    gostermek icin durur ve her guncellemede otomatik tazelenir.

    Sunucu konsolunda "config.lua dosyanizda su yeni ayarlar yok" satirini
    gorurseniz, ilgili ayari buradan kopyalayip kendi config.lua dosyaniza
    ekleyebilirsiniz.

========================================================================== ]]
--[[ ==========================================================================

    Amcaoglu Scripting — Anti-Cheat
    Destek: https://discord.gg/amcaoglu veya https://discord.gg/KNa4ugsP5P

    BU DOSYA NE İŞE YARAR?
    ----------------------
    Anti-cheat'i sunucunuza göre ayarladığınız tek dosya budur.
    Başka hiçbir dosyaya dokunmanız gerekmez.

    NASIL DÜZENLERİM?
    -----------------
      true  yazarsanız = AÇIK    (evet)
      false yazarsanız = KAPALI  (hayır)

      • Satır sonundaki virgülleri  ,  silmeyin.
      • Tırnak içindeki  "..."  yazıyı değiştirebilirsiniz,
        ama tırnakların kendisini silmeyin.

    Yanlış bir şey yazarsanız hiçbir şey bozulmaz: o ayar fabrika değerine
    döner, koruma çalışmaya devam eder ve sunucu konsoluna hangi satırda
    sorun olduğunu yazar.


    DEĞİŞİKLİK YAPTIKTAN SONRA
    --------------------------
    Dosyayı kaydedin, sunucu konsoluna şunu yazın:

        restart amcaoglu_anticheat

    Oyuncular sunucudayken yapabilirsiniz, kimse atılmaz.


    TAKILIRSANIZ
    ------------
    Aşağıda birkaç yerde "bilmiyorsanız boş bırakın" yazıyor.
    Gerçekten öyle: boş bıraktığınızda anti-cheat yine çalışır, sadece o
    özellik devre dışı kalır. Emin olmadığınız hiçbir şeyi doldurmayın,
    Discord'dan bize sorun.

========================================================================== ]]

ACAyarlar = {

    -- ======================================================================
    --  1) HANGİ KORUMALAR AÇIK OLSUN?
    --
    --     Hepsini açık bırakmanız önerilir. Bir koruma sunucunuzda soruna
    --     yol açıyorsa false yapın ve bize haber verin.
    -- ======================================================================

    -- Oyuncu silahla nişan alırken normalden hızlı koşuyor mu?
    -- İzinsiz jetpack kullanımını da bu koruma yakalar.
    hareketKorumasi = true,

    -- Araç normalden hızlı gidiyor mu, motoru kapalıyken hareket ediyor mu,
    -- aracın canı kendiliğinden doluyor mu, izinsiz nitro takılmış mı?
    aracKorumasi = true,

    -- Otomobil, motor, BMX, monster ve quad icin mutlak yatay hiz tavani.
    -- Koruma yalniz gercek surucuye ve arac zemindeyken bakar. Dusme/dikey hiz,
    -- havalanma, inisten sonraki kisa sure ve dimension/interior gecisi sayilmaz.
    aracHizKorumasi = true,
    aracMaksimumHiz = 400,

    -- Oyuncunun canı veya zırhı kendiliğinden doluyor mu?
    -- (Ölmezlik hilesi, can basma)
    canKorumasi = true,

    -- Silahla ilgili hileler:
    --   • Ateş etmediği halde karşısındakine hasar veriyor mu?
    --     (İmkânsız vuruşlar, aimbot izleri)
    --   • Silahın kaldıramayacağı hızda ateş ediyor mu? (rapid fire)
    --   • Mermisi hiç azalmıyor mu? (sonsuz mermi)
    --   • Üzerinde olmayan bir silahla ateş ediyor mu?
    silahKorumasi = true,

    -- Yukarıdaki silah korumasının alt denetimleri. silahKorumasi=false ise
    -- bu üç ayar da çalışmaz; yalnız sorun araştırırken tek tek kapatın.
    rapidFireKorumasi = true,
    sonsuzMermiKorumasi = true,
    silahSahiplikKorumasi = true,

    -- Oyuncu, elinde olmayan bir silahla bomba veya roket patlatıyor mu?
    -- Sunucudaki herkesi çökertmek için bozuk patlama paketi gönderiyor mu?
    -- Uzaktan patlama yaratıyor mu, patlama yağmuru yapıyor mu?
    --
    -- Bu koruma bozuk paketi RAPOR ETMEKLE KALMAZ, oyuna girmeden iptal eder
    -- ve elinde bomba olmayan birini İLK denemede yakalar; birkaç bomba
    -- patlamasını beklemez.
    -- Normal el bombası, roket ve satchel kullanımı etkilenmez. Hunter,
    -- Rhino ve Hydra kullanan oyuncular da etkilenmez.
    patlamaKorumasi = true,

    -- Oyuncu, çevresindeki insanları oyundan attırıyor (crash) mu?
    -- Bozuk atış paketi gönderenler yakalanır; oyunun hiç göstermediği
    -- paketlerle çökertenler ise "her çökmede orada olan kişi" mantığıyla
    -- bulunur. Tek olayda kimse cezalandırılmaz, sunucu geneli bir kesinti
    -- olduğunda da kimse suçlanmaz.
    cokmeKorumasi = true,

    -- Oyuncu, sunucudaki kendi bilgilerini (para, seviye, yetki gibi)
    -- kendi bilgisayarından değiştirmeye çalışıyor mu?
    -- Hangi bilgilerin korunacağını 6. bölümde belirleyeceksiniz.
    -- Fabrika ayarında geçici olarak kapalıdır; açılana kadar hiçbir
    -- elementData değişikliği geri alınmaz veya bu modülden raporlanmaz.
    elementDataKorumasi = false,

    -- Hangi verinin korunacağını koruma KENDİSİ öğrensin mi?
    --
    -- Açıkken anti-cheat, server tarafında yazılan her elementData
    -- anahtarını izler. Bir anahtar yalnızca server tarafından yazılıyorsa
    -- otomatik olarak korumaya alınır; o anahtara client'tan gelen her
    -- değişiklik geri alınır. Liste tutmanız gerekmez.
    --
    -- Yanlış pozitif freni var: bir anahtara 3 farklı oyuncudan yazım
    -- gelirse bu meşru client kullanımı kabul edilir ve koruma kaldırılır.
    -- Yani kendi client kodunuz sessizce bozulmaz.
    --
    -- Bu ayar, aşağıdaki korumaliOnEkler / korumaliAnahtarlar listelerinin
    -- yerine geçmez, onlara EK olarak çalışır. Elle yazdığınız anahtarlar
    -- her zaman korunur.
    --
    -- Öğrenilenlerin geri alınabilmesi için elementDataKorumasi da açık
    -- olmalıdır. Kapalıyken koruma yalnız öğrenir, müdahale etmez.
    otomatikVeriKorumasi = true,

    -- Yalnızca server'ın yazdığı elementData anahtarları.
    --
    -- BU LİSTEYİ ELLE DOLDURMAYIN. kurulum/kur.ps1 çalıştığında meta.xml'e
    -- bakıp hangi script'in client hangisinin server olduğunu ayırır ve
    -- yalnız server script'lerinde setElementData ile yazılan anahtarları
    -- buraya kendisi yazar. Kurulumu tekrar çalıştırırsanız blok yenilenir.
    --
    -- Bu anahtarlara client'tan gelen değişiklik geri alınır. Ceza üretmez:
    -- aynı anahtara 3 farklı oyuncudan yazım gelirse meşru kullanım kabul
    -- edilir ve koruma kendiliğinden kalkar. Yani kurulumun yanlış tahmin
    -- etmesi kimseyi mağdur etmez.
    sunucuVeriAnahtarlari = {
    },

    -- Oyuncu, anti-cheat'in kendi dosyasını kapatmaya çalışıyor mu?
    clientKorumasi = true,

    -- Oyuncu, oyuna dışarıdan hile kodu sokuyor mu?
    -- (Çalışması için üstteki clientKorumasi açık olmalı.)
    injectorKorumasi = true,

    -- Oyuncunun GTA klasöründe sahte dosya veya değiştirilmiş oyun
    -- dosyası var mı?
    -- Mod, ENB ve ozel model kullanan normal oyuncularda yanlis tespit
    -- uretebilecegi icin varsayilan kapalidir. Vanilla dosya zorunlulugu olan
    -- sunucular bilincli olarak true yapabilir.
    dosyaButunlugu = false,

    -- Aynı hileyi tekrar tekrar yapan oyuncu otomatik yasaklansın mı?
    -- (Süresini 3. bölümden ayarlarsınız.)
    tekrarSayaci = true,

    -- Oyuncu, sunucuya sahte bir SAYI göndermeye çalışıyor mu?
    --
    -- Bazı scriptler "kaç lira ödeneceğini" oyuncunun bilgisayarına sorar.
    -- Hileci oraya 0 yazarsa bedavaya alır. Bu koruma, her isteğe normalde
    -- hangi sayıların geldiğini KENDİSİ ÖĞRENİR ve dışına çıkanı yakalar.
    --
    -- Sizin bir şey yazmanız, liste tutmanız gerekmez. Koruma yeterince
    -- FARKLI oyuncudan örnek toplayana kadar sadece izler, sonra kendi
    -- kararını verir. Tek bir kişinin gönderdiği değer öğrenilmez; hileci
    -- kendi verisiyle sistemi kandıramaz.
    degerKorumasi = true,

    -- Öğrenme tamamlandıktan sonra aykırı sayısal değer otomatik engellensin
    -- mi? Öğrenme sırasında hiçbir paket düşmez;
    -- müşterinin rapor okuyup sonradan açması gerekmez.
    degerKorumasiEngelle = true,

    -- Değer korumasının HİÇ bakmayacağı event'ler.
    --
    -- Bazı event'ler tasarımı gereği oyuncunun kendi girdiği serbest sayıları
    -- taşır (ayar penceresi, konum/rotasyon düzenleyici, kişiselleştirme).
    -- Böyle bir argümanın kararlı bir "normal aralığı" olmaz; koruma er ya da
    -- geç onu aykırı sayıp paketi düşürür ve özellik sessizce bozulur.
    --
    -- Log'da şu satırı sürekli aynı event için görüyorsanız ve o event
    -- gerçekten oyuncunun girdiği bir sayıyı taşıyorsa buraya ekleyin:
    --   code=event_argument_outlier ... blocked=true event=<ad>
    --
    -- ÖNEMLİ: buraya eklediğiniz event'in argümanlarını artık anti-cheat
    -- doğrulamaz. O event'i kendi resource'unuzda server tarafında
    -- doğrulamanız gerekir (tip, aralık, sahiplik).
    degerKorumasiHaricEventler = {
        -- "createWeaponModel",
    },

    -- Client -> server event spam korumasi. AC her eventin normal hizini en az
    -- eventHizOgrenmeOyuncusu farkli serialdan kendisi ogrenir. Hizli silah
    -- degistirme, E/Q veya yogun UI eventleri ayri liste istemeden kendi normal
    -- zarflarina sahip olur.
    eventHizKorumasi = true,

    -- "otomatik" modda tek bir kisa tasma ceza veya rapor uretmez. Tasma ayri
    -- zaman pencerelerinde devam ederse yalniz fazla paketler dusurulur.
    -- "kapali" = devre disi, "rapor" = hic dusurme, "engelle" = ilk tasma.
    eventHizModu = "otomatik",

    -- Asagidaki ayarlar evente ozel degildir; tum sistemlere uygulanir.
    eventHizOgrenmeOyuncusu = 10,
    eventHizToleransYuzdesi = 100, -- normal tepenin ustune yuzde 100 pay
    eventHizAniPay = 4,            -- kisa paket yigilmalarina ek adet payi
    eventHizDogrulamaPenceresi = 2,
    eventHizOgrenmeOncesiTavan = 120,
    eventHizGenelTavan = 400,

    -- Buyuk ve maksimum korumali client dosyalari icin guvenli baslangic
    -- pencereleri (saniye). Sureyi client belirlemez; hileci sahte "yukleniyor"
    -- mesaji gondererek uzatamaz. Yalniz MTA'nin resource baslatma olayi ve
    -- dogrulanmis transport oturumu kabul edilir.
    clientBaslangicBeklemeSuresi = 600,
    transportElSikismaSuresi = 60,
    transportKuyrukBeklemeSuresi = 300,

    -- Oturum kurulmadan once oyuncu basina tutulabilecek server->client event.
    -- Yuksek yapmak daha cok RAM kullanir; 128 genel kullanim icin yeterlidir.
    transportKuyrukMaksimumEvent = 128,


    -- ======================================================================
    --  2) SUNUCUNUZDA NELER SERBEST?
    -- ======================================================================

    -- Jetpack yasak mı?
    -- Roleplay sunucusuysanız true bırakın.
    -- Freeroam / DM sunucusuysanız veya oyunculara jetpack veriyorsanız
    -- false yapın.
    jetpackYasak = true,

    -- Nitro yasak mı?
    -- Oyunculara nitro satıyor veya veriyorsanız false yapın.
    nitroYasak = true,


    -- ======================================================================
    --  3) CEZALAR
    --
    --     Bu bölüm sadece izinsiz jetpack kullanımı için geçerlidir.
    --     Diğer hileler zaten anında cezalandırılır.
    -- ======================================================================

    -- Aynı oyuncu kaçıncı seferde süreli yasak yesin?
    tempBanTekrarSayisi = 3,

    -- Yasak kaç saat sürsün?
    -- 24 = 1 gün    72 = 3 gün    168 = 1 hafta
    tempBanSuresiSaat = 24,


    -- ======================================================================
    --  4) OYUNCU İSMİ NEREDE YAZIYOR?
    --
    --     Bir oyuncu ceza aldığında yetkililere ve kayıtlara ismi yazılır.
    --     Çoğu roleplay sunucusu karakter ismini kendi sisteminde tutar;
    --     öyleyse o ismin nerede saklandığını buraya yazmanız gerekir.
    --
    --     BİLMİYORSANIZ boş bırakın. O zaman oyuncunun MTA nicki kullanılır,
    --     her şey yine çalışır. Doğrusunu öğrenmek için scriptinizi yazan
    --     kişiye şunu sorun:
    --         "Karakter ismini hangi elementData'da tutuyorsun?"
    -- ======================================================================

    -- Karakter isminin saklandığı yerin adı
    -- Örnek:  oyuncuIsmiVerisi = "char:name",
    oyuncuIsmiVerisi = "",

    -- Hesap / kullanıcı adının saklandığı yerin adı
    -- Örnek:  hesapIsmiVerisi = "account:username",
    hesapIsmiVerisi = "",

    -- Kayıtlarda oyuncunun bilgisayar seri numarası da yazsın mı?
    -- Ceza itirazlarında çok işinize yarar, açık bırakın.
    seriGoster = true,

    -- DİKKAT: Yukarıya bir isim yazdıysanız, aynı ismi 6. bölümdeki koruma
    -- listesine de ekleyin. Eklemezseniz hileci kendi ismini değiştirip
    -- kayıtlarda başkası gibi görünebilir.


    -- ======================================================================
    --  5) UYARILAR KİME GİTSİN?
    --
    --     Ciddi bir hile yakalandığında yetkililerin sohbet ekranına uyarı
    --     düşer. Sunucunuz "bu oyuncu yetkilidir" bilgisini nerede tutuyorsa
    --     onu buraya yazın.
    --
    --     BİLMİYORSANIZ boş bırakın. Uyarılar yine sunucu kayıtlarına düşer,
    --     sadece sohbete yazılmaz.
    -- ======================================================================

    -- Örnek:  yetkiliVerisi = { ["admin:duty"] = true },
    -- Örnek:  yetkiliVerisi = { ["yetkiliMi"] = true },
    yetkiliVerisi = {
        ["yetkili"] = true,
    },


    -- ======================================================================
    --  6) OYUNCU HANGİ BİLGİLERİNİ DEĞİŞTİREMESİN?
    --
    --     MTA'nın bilinen bir açığı var: oyuncunun bilgisayarı, sunucudaki
    --     kendi bilgilerinin çoğunu değiştirebiliyor. Yani hileci kendi
    --     parasını, seviyesini veya yetkisini kendi kendine yükseltebilir.
    --     Burası buna izin verilmeyecek bilgileri belirler.
    --
    --     Sunucunuzda para, seviye, yetki gibi şeyler hangi isimlerle
    --     saklanıyorsa onları yazacaksınız. Bilmiyorsanız scriptinizi yazan
    --     kişiden bu isimlerin listesini isteyin.
    --
    --     İKİ YOL VAR, BİRİNİ SEÇİN:
    --
    --       A YOLU  "Şunları koru" dersiniz. Yazmadıklarınız serbest kalır.
    --               Kurulumu kolaydır, varsayılan yol budur.
    --
    --       B YOLU  "Her şeyi koru, şunlar hariç" dersiniz. Daha güvenlidir;
    --               sunucunuza yarın yeni bir bilgi eklendiğinde o da
    --               kendiliğinden korunur. Kurulumu biraz daha dikkat ister.
    -- ======================================================================

    -- [A YOLU] Şu kelimelerle BAŞLAYAN bütün bilgiler korunur.
    -- Bilgileriniz "char:para", "char:seviye" gibi düzenli isimlerdeyse
    -- hepsini tek tek yazmak yerine sadece başlangıcını yazmanız yeter.
    -- Örnek:  korumaliOnEkler = { "char:", "account:", "admin:", "para:" },
    korumaliOnEkler = {
        -- Örnek (kendi ön eklerinizle değiştirin):
        -- "char:",
        -- "account:",
    },


    -- [A YOLU] Tek tek korunacak bilgiler.
    -- İsimlerin düzenli olması gerekmez, ne yazarsanız o korunur.
    -- Örnek:  korumaliAnahtarlar = { "oyuncubooster", "paraMiktari", "seviye" },
    korumaliAnahtarlar = {
        -- Örnek (kendi anahtarlarınızla değiştirin):
        -- "para",
        -- "yetkiSeviyesi",
        -- "hesapId",
    },


    -- [B YOLU] Bunu true yaparsanız yukarıdaki iki listeye gerek kalmaz.
    -- Aşağıdaki "serbestAnahtarlar" listesi dışında hiçbir bilgiyi oyuncu
    -- değiştiremez.
    --
    -- Açmadan önce aşağıdaki listeyi doldurun: sunucunuzun kendi kodu da
    -- bazı bilgileri oyuncu tarafından yazıyor olabilir. Onları listeye
    -- eklemezseniz o özellikler çalışmaz. (Oyuncu ceza almaz, o bilgi
    -- sadece kaydedilmez.)
    tumVerileriKoru = false,

    -- Oyuncunun kendi üzerinde değiştirmesinde sakınca olmayan bilgiler.
    -- Genelde AFK durumu, menü açık mı gibi zararsız şeylerdir.
    -- Örnek:  serbestAnahtarlar = { "player:afk", "ui:menuAcik" },
    serbestAnahtarlar = {
    },


    -- ======================================================================
    --  7) OYUNCU PARAMETRESİ KORUMASI
    -- ======================================================================

    -- "otomatik" = öğrenir, güven oluşunca kendisi engeller. (Önerilen)
    -- "rapor"    = öğrenir ve yalnız kayda yazar.
    -- "engelle"  = otomatik yeniden sınıflandırma olmadan zorla engeller.
    -- "kapali"   = bu koruma çalışmaz.
    oyuncuParametresiKorumasi = "otomatik",


    -- ======================================================================
    --  8) KAYITLAR
    -- ======================================================================

    -- Ayrıntılı kayıt tutulsun mu?
    -- Normalde false bırakın. Sadece bir sorunu araştırırken veya bizden
    -- destek alırken true yapın; açıkken çok fazla satır yazar.
    --
    -- KAPALIYKEN (normal kurulum): her tespit tek satır olur —
    --   [anticheat] [WARNING] <açıklama> | code=... action=... player=... serial=...
    -- AÇIKKEN: aynı satırın sonuna kanıt dökümü eklenir (konum geçmişi, hasar
    -- defteri, karar motoru ayrıntısı). Tek satır kilobaytlarca yer tutar ve
    -- konsolu boğar, bu yüzden sürekli açık bırakmayın.
    --
    -- NOT: testModu açıkken bu döküm zaten otomatik açılır; kalibrasyon
    -- sırasında ayrıca true yapmanız gerekmez.
    -- Kick ve ban islemlerinin gonderilecegi musteri Discord webhook'u.
    -- Bos birakilirsa musteri Discord logu kapali olur. Gelistirici webhook'u
    -- urunun derlenmis server tarafinda saklanir ve buradan degistirilemez.
    discordWebhook = "",

    logAyrintili = false,


    -- ======================================================================
    --  9) TEST MODU
    --
    --     DİKKAT: Bu ayarı açık bırakırsanız sunucunuz korumasız kalır.
    -- ======================================================================

    -- Test modu açıksa hile tespiti normal çalışmaya devam eder, fakat
    -- KİMSE ATILMAZ VE YASAKLANMAZ. Tespit edilen her şey sadece yetkili
    -- sohbetine ve kayıtlara "test_kick", "test_ban" olarak yazılır.
    --
    -- Test modu ayrıca ayrıntılı kanıt dökümünü açar (bkz. logAyrintili):
    -- kalibrasyon sırasında haksız tespiti incelemek için gereken veri budur.
    -- false yaptığınızda kayıtlar tekrar tek satırlık özete döner.
    --
    -- Ne zaman kullanılır?
    --   • Kurulumdan sonra, korumanın kendi oyuncularınızı yanlışlıkla
    --     yakalayıp yakalamadığını görmek için birkaç gün açık bırakın.
    --   • Kayıtlarda haksız bir tespit görürseniz bize bildirin.
    --   • Her şey temizse false yapın.
    --
    -- Açık kaldığı sürece sunucu konsoluna her başlangıçta uyarı yazılır.
    testModu = false,


    -- ======================================================================
    --  9) OTOMATİK GÜNCELLEME
    --
    --     Hile yazarları sürekli yeni yöntem deniyor. Bu yüzden otomatik
    --     güncelleme ZORUNLUDUR ve kapatılamaz; açma/kapama ayarı yoktur.
    --
    --     NASIL ÇALIŞIR?
    --       • Koruma, yeni bir sürüm var mı diye arada bir kontrol eder.
    --       • Varsa dosyaları arka planda indirir ve SHA256 ile doğrular.
    --       • Tek bir dosya bile tutmazsa hiçbir şey uygulanmaz.
    --       • Doğrulanan sürüm, resource temizce durdurulurken yerine konur
    --         ve sonraki başlangıçta devreye girer.
    --       • Sunucunuz kapanmaz, oyuncular düşmez, kimse atılmaz.
    --       • Bu dosyaya (config.lua) asla dokunmaz, ayarlarınız korunur.
    -- ======================================================================

    -- Hangi sürüm kanalı kullanılsın?
    --   "stable" = test edilmiş, önerilen. (Bunu kullanın.)
    --   "beta"   = yeni tespitlerin erken denendiği kanal. Bize yardım
    --              etmek istiyorsanız açın; yanlış tespit ihtimali vardır.
    guncellemeKanali = "stable",

    -- ================= MARKALAMA (ek hizmet) =================
    -- Bu üç ayar yalnızca whitelabel lisansı olan sunucularda çalışır.
    -- Lisansınız yoksa doldurmanızın hiçbir etkisi olmaz, varsayılan
    -- Amcaoglu-AC markalaması kullanılmaya devam eder.
    -- Lisans hakkında: https://discord.gg/amcaoglu

    -- Kick/ban ekranında, ceza duyurusunda ve yetkili uyarılarında
    -- görünecek isim. Boş bırakırsanız "Amcaoglu-AC" kullanılır.
    markaAdi = "",

    -- Markalama anahtarı. Yukarıdaki isme özeldir, destek ekibi verir.
    -- Boş bırakırsanız veya isimle eşleşmezse varsayılan markalama kullanılır.
    markaAnahtari = "",

    -- Ceza ekranında ve giriş mesajında görünecek kısa iletişim adresi.
    -- Boş bırakırsanız hiç link gösterilmez.
    markaLinki = "",

    -- Oyuncu bağlandıktan 10 saniye sonra chat'e düşen koruma mesajı
    -- gösterilsin mi? false yaparsanız hiçbir mesaj gönderilmez.
    girisMesajiGoster = true,
}
