// src/theme/mui.d.ts
import '@mui/material/Button';
import '@mui/material/Chip';
import '@mui/material/Paper';
import '@mui/material/styles';

interface GamePanelPalette {
  base: string;
  raised: string;
  sunken: string;
  border: string;
  borderMuted: string;
}

interface GameThemeTokens {
  border: {
    thin: string;
    standard: string;
    strong: string;
  };

  radius: {
    button: number;
    panel: number;
    card: number;
  };

  shadows: {
    panel: string;
    panelHover: string;
    sacred: string;
    danger: string;
    inset: string;
  };

  gradients: {
    appBackground: string;
    panel: string;
    panelRaised: string;
    sacred: string;
    primaryButton: string;
    primaryButtonHover: string;
    dangerButton: string;
    dangerButtonHover: string;
    arena: string;
  };

  textures: {
    panel: string;
    stone: string;
  };
}

declare module '@mui/material/styles' {
  interface Palette {
    gold: Palette['primary'];
    bronze: Palette['primary'];
    hellfire: Palette['primary'];
    parchment: Palette['primary'];
    sacredBlue: Palette['primary'];
    panel: GamePanelPalette;
  }

  interface PaletteOptions {
    gold?: PaletteOptions['primary'];
    bronze?: PaletteOptions['primary'];
    hellfire?: PaletteOptions['primary'];
    parchment?: PaletteOptions['primary'];
    sacredBlue?: PaletteOptions['primary'];
    panel?: Partial<GamePanelPalette>;
  }

  interface TypeBackground {
    cathedral: string;
    arena: string;
    overlay: string;
  }

  interface Theme {
    game: GameThemeTokens;
  }

  interface ThemeOptions {
    game?: GameThemeTokens;
  }
}

declare module '@mui/material/Button' {
  interface ButtonPropsVariantOverrides {
    game: true;
    sacred: true;
    danger: true;
    menu: true;
  }

  interface ButtonPropsColorOverrides {
    gold: true;
    bronze: true;
    hellfire: true;
    parchment: true;
    sacredBlue: true;
  }
}

declare module '@mui/material/Paper' {
  interface PaperPropsVariantOverrides {
    gamePanel: true;
    sacredPanel: true;
    dangerPanel: true;
  }
}

declare module '@mui/material/Chip' {
  interface ChipPropsColorOverrides {
    gold: true;
    bronze: true;
    hellfire: true;
    sacredBlue: true;
  }
}

export {};
