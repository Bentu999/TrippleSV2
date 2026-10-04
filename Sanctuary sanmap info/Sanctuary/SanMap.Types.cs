using System;
using System.Collections.Generic;

namespace EM.Map
{
    [Serializable]
    public class TextureLoader
    {
        public string path;
    }

    [Serializable]
    public class NormalTextureLoader : TextureLoader { }

    [Serializable]
    public class MaskTextureLoader : TextureLoader { }

    public enum SkyIntensityMode
    {
        /// <summary>Intensity is expressed as an exposure.</summary>
        Exposure,
        /// <summary>Intensity is expressed in lux.</summary>
        Lux,
        /// <summary>Intensity is expressed as a multiplier.</summary>
        Multiplier,
    }

    [Serializable]
    public class Stratum
    {
        public string name;
        public TextureLoader albedo;
        public NormalTextureLoader normal;
        public MaskTextureLoader mask;
        public Vector2 tileSize;
        public Vector2 tileSizeFar;
        public float tileSizeTriplanar;
        public float tileSizeFarTriplanar;
        public float normalScale;
        public float normalScaleFar;
        public float normalFarNearBlend = 0.5f;
        public float heightFarNearBlend = 0.5f;
        public Color diffuseRemap;
        public Color farColorRemap;
        public Vector4 maskRemapMin;
        public Vector4 maskRemapMax;

        public Stratum()
        {
            albedo = new TextureLoader();
            normal = new NormalTextureLoader();
            mask = new MaskTextureLoader();
            tileSize = new Vector2(1, 1);
            tileSizeFar = new Vector2(1, 1);
            tileSizeTriplanar = 12f;
            tileSizeFarTriplanar = 36f;
            normalScale = 1f;
            normalScaleFar = 1f;
            normalFarNearBlend = 0.5f;
            heightFarNearBlend = 0.5f;
            diffuseRemap = new Color(0.5f, 0.5f, 0.5f, 1f); // Gray.
            farColorRemap = new Color(1f, 1f, 1f, 0f);
            maskRemapMin = new Vector4(0, 0, 0, 0);
            maskRemapMax = new Vector4(1f, 1f, 1f, 1f);
        }
    }

    [Serializable]
    public class Area
    {
        public float x;
        public float y;
        public float width;
        public float height;
        public Area(float x, float y, float width, float height) { this.x = x; this.y = y; this.width = width; this.height = height; }
    }

    [Serializable]
    public class Army
    {
        public int faction; //0, 1, 2
        public float alloys;
        public float energy;
        public Dictionary<string, UnitGroup> groups = new Dictionary<string, UnitGroup>();
    }

    [Serializable]
    public class UnitGroup
    {
        public Dictionary<string, UnitTransform> units = new Dictionary<string, UnitTransform>();
        public Dictionary<string, UnitGroup> groups = new Dictionary<string, UnitGroup>();
    }

    [Serializable]
    public class UnitTransform : InstancedTransform
    {
        public string type;
        public string tpid;

        public UnitTransform(Vector3 Position, Quaternion Rotation, Vector3 Scale)
        {
            position = Position;
            rotation = Rotation;
            scale = Scale;
        }
    }

    [Serializable]
    public class PropType
    {
        public string blueprintPath;
        public List<PropTransform> transforms = new List<PropTransform>();
    }

    [Serializable]
    public class PropTransform : InstancedTransform
    {
        public PropTransform(Vector3 Position, Quaternion Rotation, Vector3 Scale)
        {
            position = Position;
            rotation = Rotation;
            scale = Scale;
        }
    }

    [Serializable]
    public class DecalType
    {
        public string blueprintPath;
        public List<DecalTransform> transforms;
    }

    [Serializable]
    public class DecalTransform : InstancedTransform
    {
        public DecalTransform(Vector3 Position, Quaternion Rotation, Vector3 Scale)
        {
            position = Position;
            rotation = Rotation;
            scale = Scale;
        }
    }

    [Serializable]
    public class MarkerChain
    {
        public Marker[] markers;

        [Serializable]
        public struct Marker
        {
            public string type;
            public string name;

            public Marker(string type, string name) { this.type = type; this.name = name; }
        }

    }

    [Serializable]
    public class MarkerType
    {
        public bool resource = false;
        public Dictionary<string, MarkerTransform> transforms = new Dictionary<string, MarkerTransform>(64);
    }

    [Serializable]
    public class MarkerTransform : InstancedTransform
    {
        public MarkerTransform(Vector3 Position, Quaternion Rotation, Vector3 Scale)
        {
            position = Position;
            rotation = Rotation;
            scale = Scale;
        }
    }

    [Serializable]
    public class InstancedTransform
    {
        public Vector3 position;
        public Quaternion rotation;
        public Vector3 scale;
    }
}