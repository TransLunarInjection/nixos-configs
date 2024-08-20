{ pkgs, lib, ... }:
# Using a much more minimal set of system fonts now because
# battle.net seems to break if there are lots of fonts
let lotsOfFonts = false;
in
{
  fonts = {
    enableDefaultPackages = false;

    packages = lib.mkForce (with pkgs; [
      dejavu_fonts
      freefont_ttf
      gyre-fonts # TrueType substitutes for standard PostScript fonts
      liberation_ttf
      unifont
      vistafonts # Calibri, Cambria, Candara, Consolas, Constantia, Corbel
      fira-code # use in emacs
      #(nerdfonts.override { fonts = [ "Hack" ]; })
      twitter-color-emoji # Decent set of emoji
      font-awesome_6

      symbola # only font with alchemical symbol block?
    ] ++ lib.optionals lotsOfFonts [
      # General fonts
      noto-fonts
      noto-fonts-cjk
      liberation_ttf
      ttf_bitstream_vera

      # Japanese
      ipafont
      kochi-substitute

      # Code/monospace and nsymbol fonts
      fira-code
      fira-code-symbols
      mplus-outline-fonts.osdnRelease
      dina-font
      proggyfonts
      font-awesome_4
      font-awesome_5
      dejavu_fonts
      source-code-pro
      iosevka-bin

      # Emoji
      noto-fonts-emoji
      noto-fonts-extra
    ]);

    # # Lucida -> iosevka as no free Lucida font available and it's used widely
    fontconfig.localConf = lib.mkIf lotsOfFonts ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
      <fontconfig>
        <match target="pattern">
          <test name="family" qual="any"><string>Lucida</string></test>
          <edit name="family" mode="assign">
            <string>iosevka</string>
          </edit>
        </match>
         <match target="font">
          <edit mode="assign" name="rgba">
          <const>none</const>
          </edit>
        </match>
        <match target="font">
          <edit mode="assign" name="hinting">
          <bool>true</bool>
          </edit>
        </match>
        <match target="font">
          <edit mode="assign" name="hintstyle">
          <const>hintfull</const>
          </edit>
        </match>
        <match target="font">
          <edit mode="assign" name="antialias">
          <bool>true</bool>
          </edit>
        </match>
      </fontconfig>
    '';
  };
}
