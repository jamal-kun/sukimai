-- SCRIPT FINAL: TOTAL WIPE ALL MAP & EFFECTS (JX Market)
local function JXMarketTotalClean()
    -- 1. NOTIFIKASI POPUP (Tanda Script Aktif)
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "JX MARKET AKTIF",
        Text = "AFK Tahan Banting",
        Duration = 10
    })

    -- 2. KINERJA ANTI-LAG (Mencegah Force Close)
    setfpscap(15) -- Kunci FPS rendah agar HP dingin
    settings().Rendering.QualityLevel = 1
    
    -- 3. FUNGSI PEMBERSIH REKURSIF (Sangat Kuat)
    local function ForceWipe(obj)
        -- Hapus Efek (Partikel, Cahaya, Trail)
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Light") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj.Enabled = false
        
        -- Paksa Map Abu-abu & Hapus Tekstur (Tanah, Pohon, Bangunan)
        elseif obj:IsA("BasePart") or obj:IsA("MeshPart") then
            obj.Material = Enum.Material.SmoothPlastic
            obj.Color = Color3.fromRGB(120, 120, 120)
            obj.Reflectance = 0
            obj.CastShadow = false
            
            -- Menghapus ID Tekstur agar warna asli benar-benar hilang
            if obj:IsA("MeshPart") then
                obj.TextureID = ""
            end
            
        -- Hapus Gambar/Decal yang menempel
        elseif obj:IsA("Decal") or obj:IsA("Texture") then
            obj:Destroy()
        end
    end

    -- 4. EKSEKUSI KE SELURUH MAP (ALL MAP)
    -- Membersihkan semua yang sudah ada sekarang
    for _, v in pairs(game:GetDescendants()) do
        ForceWipe(v)
    end

    -- Otomatis bersihkan map baru saat kamu pindah lokasi (Streaming)
    game.DescendantAdded:Connect(ForceWipe)

    -- 5. MATIKAN PENCAHAYAAN GLOBAL (Hapus Silau)
    local lighting = game.Lighting
    lighting.GlobalShadows = false
    lighting.Brightness = 0.5
    for _, effect in pairs(lighting:GetChildren()) do
        if effect:IsA("PostEffect") or effect:IsA("BloomEffect") or effect:IsA("SunRaysEffect") then
            effect.Enabled = false
        end
    end

    -- Membersihkan memori RAM secara berkala agar tidak Force Close
    task.spawn(function()
        while task.wait(5) do
            collectgarbage("collect")
        end
    end)
end

-- Jalankan Fungsi
JXMarketTotalClean()
