using System.Collections.Generic;

namespace EM.Map
{
    public static class Colors
    {
        public static readonly Color EDADefault = new Color(0.078f, 0.329f, 0.196f, 1); // dark green
        public static readonly Color ChosenDefault = new Color(0.412f, 0.008f, 0.008f, 1); // dark red
        public static readonly Color GuardDefault = new Color(0.690f, 0.549f, 0.188f, 1); // golden amber
        public static readonly Color Blue = new Color(0.227f, 0.373f, 0.804f, 1);
        public static readonly Color BrightRed = new Color(0.910f, 0.039f, 0.039f, 1);
        public static readonly Color EmeraldGreen = new Color(0.180f, 0.545f, 0.341f, 1);
        public static readonly Color VividYellow = new Color(0.980f, 0.980f, 0.000f, 1);
        public static readonly Color WarmOrange = new Color(1.000f, 0.529f, 0.243f, 1);
        public static readonly Color LightBlue = new Color(0.180f, 0.455f, 0.863f, 1);
        public static readonly Color SkyBlue = new Color(0.310f, 0.580f, 0.804f, 1);
        public static readonly Color DarkSlateBlue = new Color(0.282f, 0.239f, 0.545f, 1);
        public static readonly Color GrayishBlue = new Color(0.380f, 0.427f, 0.494f, 1);
        public static readonly Color DeepBlue = new Color(0.161f, 0.161f, 0.882f, 1);
        public static readonly Color Gray = new Color(0.502f, 0.502f, 0.502f, 1);
        public static readonly Color Aqua = new Color(0.208f, 0.851f, 0.851f, 1);
        public static readonly Color SalmonRed = new Color(0.800f, 0.322f, 0.322f, 1);
        public static readonly Color LightGray = new Color(0.816f, 0.816f, 0.816f, 1);
        public static readonly Color Lavender = new Color(0.804f, 0.710f, 0.804f, 1);
        public static readonly Color PalePink = new Color(1.000f, 0.757f, 0.757f, 1);
        public static readonly Color White = new Color(1.000f, 1.000f, 1.000f, 1);
        public static readonly Color Yellow = new Color(1.000f, 1.000f, 0.000f, 1);
        public static readonly Color ForestGreen = new Color(0.133f, 0.545f, 0.133f, 1);
        public static readonly Color DarkSlateGray = new Color(0.184f, 0.310f, 0.310f, 1);
        public static readonly Color BrightGreen = new Color(0.000f, 1.000f, 0.000f, 1);

        public static readonly Color Magenta = new Color(0.9137f, 0.1176f, 0.5490f, 1); // E9 1E 8C
        public static readonly Color Amber = new Color(0.9020f, 0.6235f, 0.0000f, 1); // E6 9F 00
        public static readonly Color CyanBlue = new Color(0.3373f, 0.7059f, 0.9137f, 1); // 56 B4 E9
        public static readonly Color TealGreen = new Color(0.0000f, 0.6196f, 0.4510f, 1); // 00 9E 73
        public static readonly Color PaleYellow = new Color(0.9412f, 0.8941f, 0.2588f, 1); // F0 E4 42
        public static readonly Color CobaltBlue = new Color(0.0000f, 0.4471f, 0.6980f, 1); // 00 72 B2
        public static readonly Color Vermillion = new Color(0.8353f, 0.3686f, 0.0000f, 1); // D5 5E 00
        public static readonly Color DustyMauve = new Color(0.8000f, 0.4745f, 0.6549f, 1); // CC 79 A7

        public static readonly Dictionary<string, Color> ColorLookup = new Dictionary<string, Color>
        {
            // Original colors
            ["EDADefault"] = EDADefault, // dark green
            ["ChosenDefault"] = ChosenDefault, // dark red
            ["GuardDefault"] = GuardDefault, // golden amber
            ["Blue"] = Blue,
            ["BrightRed"] = BrightRed,
            ["EmeraldGreen"] = EmeraldGreen,
            ["VividYellow"] = VividYellow,
            ["WarmOrange"] = WarmOrange,
            ["LightBlue"] = LightBlue,
            ["SkyBlue"] = SkyBlue,
            ["DarkSlateBlue"] = DarkSlateBlue,
            ["GrayishBlue"] = GrayishBlue,
            ["DeepBlue"] = DeepBlue,
            ["Gray"] = Gray,
            ["Aqua"] = Aqua,
            ["SalmonRed"] = SalmonRed,
            ["LightGray"] = LightGray,
            ["Lavender"] = Lavender,
            ["PalePink"] = PalePink,
            ["White"] = White,
            ["Yellow"] = Yellow,
            ["ForestGreen"] = ForestGreen,
            ["DarkSlateGray"] = DarkSlateGray,
            ["BrightGreen"] = BrightGreen,

            // Extra
            ["Magenta"] = Magenta,
            ["Amber"] = Amber,
            ["CyanBlue"] = CyanBlue,
            ["TealGreen"] = TealGreen,
            ["PaleYellow"] = PaleYellow,
            ["CobaltBlue"] = CobaltBlue,
            ["Vermillion"] = Vermillion,
            ["DustyMauve"] = DustyMauve,
        };

        public readonly static Color[] ArmyColors = new Color[] 
        {
            EDADefault,
            ChosenDefault,
            GuardDefault,
            DeepBlue,
            BrightRed,
            EmeraldGreen,
            VividYellow,
            WarmOrange,
            Blue,
            LightBlue,
            SkyBlue,
            DarkSlateBlue,
            GrayishBlue,
            Gray,
            Aqua,
            SalmonRed,
            LightGray,
            Lavender,
            PalePink,
            White,
            Yellow,
            ForestGreen,
            DarkSlateGray,
            BrightGreen,

            Magenta,
            Amber,
            CyanBlue,
            TealGreen,
            PaleYellow,
            CobaltBlue,
            Vermillion,
            DustyMauve,
        };
    }
}
