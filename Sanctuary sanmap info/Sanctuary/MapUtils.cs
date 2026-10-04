using System;
using System.Collections.Generic;

namespace EM.Map
{
    public static class MapUtils
    {
        const string ArmySpawnMarker = "Spawn";
        const string PlayableAreaName = "PlayableArea";
        const string AlloySpotMarker = "Alloys";

        /// <summary>
        /// Take existing format and covert it to the new Sanctuary format I imported. Mostly because I have yet to understand everything so it is easier for me to do this here.
        /// </summary>
        /// <param name="map"></param>
        /// <returns></returns>
        public static SanMap GetSanMap(ExtraneousMapGen.map.SanMap map)
        {
            var sanmap = new SanMap();

            sanmap.fileVersion = map.FileVersion;
            sanmap.mapVersion = map.MapVersion;
            sanmap.name = map.Name;
            sanmap.credits = map.Credits;
            sanmap.width = map.Width;
            sanmap.length = map.Length;
            sanmap.height = map.Height;

            sanmap.heightmapResolution = map.RawHeightmap.Size;

            var biome = map.Biome;

            // Water levels come from the map: generators mutate and scale the working
            // copies, the biome itself stays raw data.
            sanmap.hasWater = map.WaterLevel > 0;
            sanmap.waterLevel = map.WaterLevel;
            sanmap.waterDepth = map.WaterDepth;
            sanmap.waterWindSpeed = biome.waterSettings.waterWindSpeed;
            sanmap.waterWindDirection = biome.waterSettings.waterWindDirection;
            sanmap.waterWindShoreWavesRemap = biome.waterSettings.waterWindShoreWavesRemap;
            sanmap.waterShoreDepthOffset = biome.waterSettings.waterShoreDepthOffset;
            sanmap.waterShoreDepthStrength = biome.waterSettings.waterShoreDepthStrength;
            sanmap.waterShoreDistanceOffset = biome.waterSettings.waterShoreDistanceOffset;
            sanmap.waterShoreDistanceStrength = biome.waterSettings.waterShoreDistanceStrength;
            sanmap.waterShoreGeneratorBlueprint = biome.waterSettings.waterShoreGeneratorBlueprint;

            sanmap.shader = biome.textureSettings.shader;
            sanmap.heightTransition = biome.textureSettings.heightTransition;
            sanmap.fadeDistance = biome.textureSettings.fadeDistance;
            sanmap.fadeStartDistance = biome.textureSettings.fadeStartDistance;
            sanmap.stratumLayers = biome.textureSettings.stratumLayers;

            sanmap.backgroundFogIntensity = biome.fogSettings.backgroundFogIntensity;
            sanmap.backgroundFogRange = biome.fogSettings.backgroundFogRange;
            sanmap.backgroundFogMinimum = biome.fogSettings.backgroundFogMinimum;
            sanmap.backgroundSkyColorIntensity = biome.fogSettings.backgroundSkyColorIntensity;
            sanmap.backgroundColorIntensity = biome.fogSettings.backgroundColorIntensity;
            sanmap.backgroundColor = biome.fogSettings.backgroundColor;
            sanmap.backgroundColorFadeoutRange = biome.fogSettings.backgroundColorFadeoutRange;
            sanmap.backgroundColorFadeoutPower = biome.fogSettings.backgroundColorFadeoutPower;

            sanmap.heightFogIntensity = biome.fogSettings.heightFogIntensity;
            sanmap.heightFogRange = biome.fogSettings.heightFogRange;
            sanmap.heightFogStart = biome.fogSettings.heightFogStart;
            sanmap.heightFogEnd = biome.fogSettings.heightFogEnd;
            sanmap.heightFogPower = biome.fogSettings.heightFogPower;

            sanmap.linearFogIntensity = biome.fogSettings.linearFogIntensity;
            sanmap.linearFogStart = biome.fogSettings.linearFogStart;
            sanmap.linearFogEnd = biome.fogSettings.linearFogEnd;
            sanmap.linearFogPower = biome.fogSettings.linearFogPower;
            sanmap.linearFogCameraIntensity = biome.fogSettings.linearFogCameraIntensity;
            sanmap.linearFogCameraStart = biome.fogSettings.linearFogCameraStart;
            sanmap.linearFogCameraEnd = biome.fogSettings.linearFogCameraEnd;

            sanmap.fogAttenuationDistance = biome.fogSettings.fogAttenuationDistance;
            sanmap.fogBaseHeight = biome.fogSettings.fogBaseHeight;
            sanmap.fogMaximumHeight = biome.fogSettings.fogMaximumHeight;
            sanmap.fogMaximumDistance = biome.fogSettings.fogMaximumDistance;
            sanmap.fogAnisotropy = biome.fogSettings.fogAnisotropy;

            sanmap.sunRA = biome.lightSettings.sunRA;
            sanmap.sunDA = biome.lightSettings.sunDA;
            sanmap.sunIntensity = biome.lightSettings.sunIntensity;
            sanmap.sunTint = biome.lightSettings.sunTint;
            sanmap.sunTemperature = biome.lightSettings.sunTemperature;
            sanmap.sunAngularDiameter = biome.lightSettings.sunAngularDiameter;
            sanmap.sunVolumetricsMultiplier = biome.lightSettings.sunVolumetricsMultiplier;
            sanmap.sunVolumetricsShadowDimer = biome.lightSettings.sunVolumetricsShadowDimer;
            sanmap.sunPosition = biome.lightSettings.sunPosition;
            sanmap.sunCookie = biome.lightSettings.sunCookie;
            sanmap.sunCookieSize = biome.lightSettings.sunCookieSize;

            sanmap.skylightIntensity = biome.lightSettings.skylightIntensity;
            sanmap.skylightTint = biome.lightSettings.skylightTint;
            sanmap.skylightTemperature = biome.lightSettings.skylightTemperature;
            sanmap.exposure = biome.lightSettings.exposure;
            sanmap.exposureCompensation = biome.lightSettings.exposureCompensation;
            sanmap.skyboxRotation = biome.lightSettings.skyboxRotation;
            sanmap.skyboxIntensityMode = biome.lightSettings.skyboxIntensityMode;
            sanmap.skyboxExposure = biome.lightSettings.skyboxExposure;
            sanmap.skyboxMultiplier = biome.lightSettings.skyboxMultiplier;
            sanmap.skyboxLuxValue = biome.lightSettings.skyboxLuxValue;
            sanmap.skybox = biome.lightSettings.skybox;

            {   // Armies
                sanmap.armies = new Dictionary<string, Army>(map.Armies.Count);
                foreach (var army in map.Armies)
                {
                    sanmap.armies.Add(army.Id, new Army { faction = 0, alloys = 500, energy = 500, groups = new Dictionary<string, UnitGroup>() });
                }
            }

            // All locations are in the map's texture coordinates which start from the top left of the texture.
            // Sanctuary maps use markers from the world origin which is the bottom left of the map.

            {   // Army spawns
                var spawnLocations = new Dictionary<string, MarkerTransform>(map.Spawns.Count);
                foreach (var spawns in map.Spawns)
                {
                    spawnLocations.Add(spawns.Id, new MarkerTransform(TextureToWorldOrigin(spawns.Position, map.Length), new Quaternion(), new Vector3(1, 1, 1)));
                }
                sanmap.markers.Add(ArmySpawnMarker, new MarkerType
                {
                    resource = false,
                    transforms = spawnLocations,
                });
            }

            {   // Alloy spots
                var alloySpots = new Dictionary<string, MarkerTransform>(map.Mexes.Count);
                foreach (var mex in map.Mexes)
                {
                    if (alloySpots.ContainsKey(mex.Id) == false)
                    {
                        alloySpots.Add(mex.Id, new MarkerTransform(TextureToWorldOrigin(mex.Position, map.Length), new Quaternion(), new Vector3(1, 1, 1)));
                    }
                    else
                    {
                        Console.WriteLine($"Error: Could not add MexId: {mex.Id} as an alloy spot. MexId: {mex.Id} already exists as an alloy spot. If this is a different mex, please ensure the name is unique.");
                    }

                }
                sanmap.markers.Add(AlloySpotMarker, new MarkerType
                {
                    resource = true,
                    transforms = alloySpots,
                });
            }

            // Playable Area
            sanmap.areas.Add(PlayableAreaName, new Area(map.PlayableArea.GetX(), map.PlayableArea.GetY(), map.PlayableArea.GetZ(), map.PlayableArea.GetW()));

            {   // Decals
                var decals = new DecalType[map.DecalGroups.Count];
                for (int i = 0; i < decals.Length; i++)
                {
                    var decalGroup = map.DecalGroups[i];

                    var transforms = new List<DecalTransform>(decalGroup.Transforms.Count);

                    for (int j = 0; j < decalGroup.Transforms.Count; j++)
                    {
                        var transform = decalGroup.Transforms[j];
                        // TODO: Convert the transform.rotation angles to quaternion. 
                        transforms.Add(new DecalTransform(TextureToWorldOrigin(transform.Position, map.Length), new Quaternion(), transform.Scale));
                    }

                    decals[i] = new DecalType 
                    { 
                        blueprintPath = decalGroup.BlueprintPath, 
                        transforms = transforms,
                    };
                }
                sanmap.decals = decals;
            }

            // We ignore props for now. Many of the prop formats are outdated causing maps to fail loading.
            //{   // Props
            //    var props = new PropType[map.PropGroups.Count];
            //    for (int i = 0; i < map.PropGroups.Count; i++)
            //    {
            //        var propGroup = map.PropGroups[i];

            //        var transforms = new List<PropTransform>(propGroup.Transforms.Count);

            //        for (int j = 0; j < propGroup.Transforms.Count; j++)
            //        {
            //            var transform = propGroup.Transforms[j];
            //            // TODO: Convert the transform.rotation angles to quaternion. 
            //            transforms.Add(new PropTransform(TextureToWorldOrigin(transform.Position, map.Length), new Quaternion(), transform.Scale));
            //        }

            //        props[i] = new PropType
            //        {
            //            blueprintPath = propGroup.BlueprintPath,
            //            transforms = transforms,
            //        };
            //    }
            //    sanmap.props = props;
            //}

            return sanmap;
        }

        private static Vector3 TextureToWorldOrigin(Vector3 texturePosition, int textureHeight)
        {
            return new Vector3(texturePosition.x, texturePosition.y, textureHeight - texturePosition.z - 1);
        }
    }
}
