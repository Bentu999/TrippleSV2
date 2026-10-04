using System;

namespace EM.Map
{
    [Serializable]
    public class Vector2
    {
        public float x, y;

        public Vector2(float x, float y)
        {
            this.x = x;
            this.y = y;
        }

        public static implicit operator Vector2(ExtraneousMapGen.util.Vector2 value) => new Vector2(value.GetX(), value.GetY());
    }

    [Serializable]
    public class Vector3
    {
        public float x, y, z;

        public Vector3(float x, float y, float z)
        {
            this.x = x;
            this.y = y;
            this.z = z;
        }

        public static implicit operator Vector3(ExtraneousMapGen.util.Vector3 value) => new Vector3(value.GetX(), value.GetY(), value.GetZ());
    }

    [Serializable]
    public class Vector4
    {
        public float x, y, z, w;

        public Vector4(float x, float y, float z, float w)
        {
            this.x = x;
            this.y = y;
            this.z = z;
            this.w = w;
        }

        public static implicit operator Vector4(ExtraneousMapGen.util.Vector4 value) => new Vector4(value.GetX(), value.GetY(), value.GetZ(), value.GetW());
    }

    [Serializable]
    public class Quaternion
    {
        public float x, y, z, w;

        public Quaternion() : this(0, 0, 0, 1) { }

        public Quaternion(float x, float y, float z, float w)
        {
            this.x = x;
            this.y = y;
            this.z = z;
            this.w = w;
        }

        public static implicit operator Quaternion(ExtraneousMapGen.util.Vector4 value) => new Quaternion(value.GetX(), value.GetY(), value.GetZ(), value.GetW());
    }

    [Serializable]
    public class Color
    {
        public float r, g, b, a;

        public Color(float r, float g, float b, float a)
        {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public static implicit operator Color(ExtraneousMapGen.util.Vector4 value) => new Color(value.GetX(), value.GetY(), value.GetZ(), value.GetW());
    }
}
