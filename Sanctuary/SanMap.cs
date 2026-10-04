using System;
using System.Collections.Generic;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;

namespace EM.Map
{
    [Serializable]
    public partial class SanMap
    {
        const int FORMAT_VERSION = 3;
        public const string EXTENSION = ".sanmap";
        public const string EXTENSION_NODOT = "sanmap";
        public const int STRATUM_COUNT = 9;
        
        #region Base

        public int fileVersion;
        public int mapVersion;
        public string name;
        public string credits;
        public int width;
        public int length;
        public int height;

        #endregion // Base

        #region Shape

        public int heightmapResolution;

        #endregion // Shape

        #region Water

        public bool hasWater = false;
        public float waterLevel = 0f;
        public float waterDepth = 8f;
        public float waterWindSpeed = 0.25f;
        public float waterWindDirection = 160f;
        public float waterWindShoreWavesRemap = 0.5f;
        public float waterShoreDepthOffset = 8f;
        public float waterShoreDepthStrength = 0.7f;
        public float waterShoreDistanceOffset = 0;
        public float waterShoreDistanceStrength = 2;

        public string waterShoreGeneratorBlueprint = "";

        #endregion // Water

        #region Texturing

        // Basically always "RTS/TerrainLit";
        public string shader = "RTS/TerrainLit";

        // So to be honest I am just going to put random ones I guess.
        public float heightTransition;  // Random, unknown value.
        public float fadeDistance;      // Random, unknown value.
        public float fadeStartDistance; // Random, unknown value.

        public Stratum[] stratumLayers = new Stratum[0];

        #endregion // Texturing

        #region Background
        public float backgroundFogIntensity = 1.0f;
        public float backgroundFogRange = 1024;
        public float backgroundFogMinimum = 0.1f;
        public float backgroundSkyColorIntensity = 1.0f;
        public float backgroundColorIntensity = 0.0f;
        public Color backgroundColor = new Color(0.0f, 0.0f, 0.0f, 1.0f);
        public float backgroundColorFadeoutRange = 150000;
        public float backgroundColorFadeoutPower = 0.3f;
        #endregion // Background

        #region HeightFog
        //[Range(0f, 1f)]
        public float heightFogIntensity = 1f;
        public Vector2 heightFogRange = new Vector2(-10f, 100f);
        public float heightFogStart = -10f;
        public float heightFogEnd = 500f;
        //[Range(0.001f, 6f)]
        public float heightFogPower = 6f;
        #endregion HeightFog

        #region LinearFog
        //[Range(0f, 1f)]
        public float linearFogIntensity = 0.24f;
        //[Min(0f)]
        public float linearFogStart = 100;
        //[Min(0.001f)]
        public float linearFogEnd = 5000f;
        //[Range(0.001f, 6f)]
        public float linearFogPower = 1f;
        //[Range(0f, 1f)]
        public float linearFogCameraIntensity = 0f;
        public float linearFogCameraStart = 500;
        //[Min(0.001f)]
        public float linearFogCameraEnd = 5000;
        #endregion LinearFog

        #region Lighting

        public float sunRA;
        public float sunDA;
        public float sunIntensity;
        public Color sunTint;
        public float sunTemperature;
        public float sunAngularDiameter;
        public float sunVolumetricsMultiplier;
        public float sunVolumetricsShadowDimer;
        public Vector3 sunPosition = new Vector3(512, 10, 256);

        // There is time has this. Need to check if this is even used.
        //"sunCookie": {
        //  "path": "Environment/Skybox/CloudsCookie.dds"
        //},
        //"sunCookieSize": {
        //  "x": 1024.0,
        //  "y": 1024.0
        //},

        public TextureLoader sunCookie = new TextureLoader { path = "Environment/Skybox/CloudsCookie.dds" };
        public Vector2 sunCookieSize = new Vector2(1024.0f, 1024.0f); // Random, unknown value.

        public float skylightIntensity = 0;
        public Color skylightTint = new Color(1.0f, 1.0f, 1.0f, 1.0f);
        public float skylightTemperature = 9000;
        public float exposure;                          // Random, unknown value.
        public float exposureCompensation;              // Random, unknown value.
        public float skyboxRotation = 0;
        [JsonConverter(typeof(StringEnumConverter))] 
        public SkyIntensityMode skyboxIntensityMode = SkyIntensityMode.Exposure;

        public float skyboxExposure = 12;
        public float skyboxMultiplier = 1;
        public float skyboxLuxValue = 10000;
        public float fogAttenuationDistance;// Random, unknown value.
        public float fogBaseHeight;         // Random, unknown value.
        public float fogMaximumHeight;      // Random, unknown value.
        public float fogMaximumDistance;    // Random, unknown value.
        public float fogAnisotropy;         // Random, unknown value.
        public TextureLoader skybox = new TextureLoader();

        #endregion // Lighting

        public Dictionary<string, Area> areas = new Dictionary<string, Area>();
        public Dictionary<string, Army> armies = new Dictionary<string, Army>(16);

        public Dictionary<string, MarkerChain.Marker[]> chains = new Dictionary<string, MarkerChain.Marker[]>(32);
        public Dictionary<string, MarkerType> markers = new Dictionary<string, MarkerType>(32);

        public DecalType[] decals = new DecalType[0];

        public float windSpeed = 0.25f;
        public float windDirection = 160f;
        public PropType[] props = new PropType[0];

        public SanMap(string path = null)
        {
            mapVersion = 1;
            fileVersion = FORMAT_VERSION;
            //if (path != null)
            //{
            //    LoadJson(path);
            //}
        }

        public void Clear()
        {
            fileVersion = 0;
            mapVersion = 0;
            width = 32;
            length = 32;
            height = 128;
            credits = "";
            name = "";

            heightmapResolution = 0;

            waterLevel = 0;
            waterDepth = 0;

            shader = "RTS/TerrainLit";
            heightTransition = 0.5f;
            fadeDistance = 128f;
            fadeStartDistance = 1f;

            stratumLayers = new Stratum[STRATUM_COUNT];
            for (int i = 0; i < STRATUM_COUNT; i++)
                stratumLayers[i] = new Stratum();

            sunRA = 0;
            sunDA = 0;
            sunIntensity = 15000;
            sunTint = new Color(1.0f, 1.0f, 1.0f, 1.0f);
            sunTemperature = 6300;
            sunAngularDiameter = 0.5f;
            sunVolumetricsMultiplier = 6.7f;
            sunVolumetricsShadowDimer = 0.5f;
            sunPosition = new Vector3(512, 10, 256);
            sunCookie.path = "";
            sunCookieSize = new Vector2(1024, 1024);
            exposure = 12;
            exposureCompensation = 2.5f;
            skyboxRotation = 0;
            skyboxIntensityMode = SkyIntensityMode.Exposure;
            skyboxExposure = 12;
            skyboxMultiplier = 1;
            skyboxLuxValue = 10000;
            fogAttenuationDistance = 200;
            fogBaseHeight = 15;
            fogMaximumHeight = 100;
            fogMaximumDistance = 1500;
            fogAnisotropy = 0.5f;
            skybox.path = "";

            waterShoreGeneratorBlueprint = "";

            decals = new DecalType[0];

            props = new PropType[0];
        }
    }
}