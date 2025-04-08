import ReactNativeBlobUtil, { type FetchBlobResponse } from 'react-native-blob-util';
import type { ModelName } from '.';

export const TARGET_DIR = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/react_native_wfloat`;
export const CONFIG_FILE_PATH = `${TARGET_DIR}/models_config.json`;
export const AUDIO_OUTPUT_SAVE_LIMIT = 100;
// export const AUDIO_OUTPUT_SAVE_LIMIT = 3;
let operationQueue = Promise.resolve(); // Ensures sequential execution

export async function readConfig(): Promise<WfloatConfig> {
    try {
        const exists = await ReactNativeBlobUtil.fs.exists(CONFIG_FILE_PATH);
        if (!exists) {
            await ReactNativeBlobUtil.fs.writeFile(CONFIG_FILE_PATH, JSON.stringify({
                models: {},
                outputs: [],
            }), 'utf8');
            return {
                models: {},
                outputs: [],
            };
        };

        const content = await ReactNativeBlobUtil.fs.readFile(CONFIG_FILE_PATH, 'utf8');
        return JSON.parse(content);
    } catch (error) {
        console.error("Error reading config:", error);
        await ReactNativeBlobUtil.fs.writeFile(CONFIG_FILE_PATH, JSON.stringify({
            models: {},
            outputs: [],
        }), 'utf8');
        return {
            models: {},
            outputs: [],
        };
    }
}

async function writeConfig(updatedConfig: WfloatConfig) {
    try {
        const jsonString = JSON.stringify(updatedConfig, null, 2);
        await ReactNativeBlobUtil.fs.writeFile(CONFIG_FILE_PATH, jsonString, 'utf8');
    } catch (error) {
        console.error("Error writing config:", error);
    }
}

async function modifyConfig(modifierFn: (config: WfloatConfig) => WfloatConfig) {
    return operationQueue = operationQueue.then(async () => {
        const config = await readConfig();
        const updatedConfig = modifierFn(config);
        await writeConfig(updatedConfig);
    });
}

type ModelConfigEntry = {
    id: ModelName,
    configPath: string,
    modelPath: string,
    version: 0,
}
type WfloatConfig = {
    models: Record<string, ModelConfigEntry>,
    outputs: string[]
}

async function updateLoadedModelEntry(modelConfigEntry: ModelConfigEntry) {
    await modifyConfig(config => {
        const modelEntries = { ...config.models, [modelConfigEntry.id]: modelConfigEntry, }
        return {
            ...config,
            models: modelEntries,
        };
    });
}

async function removeLoadedModelEntry(modelName: ModelName) {
    await modifyConfig(config => {
        const { [modelName]: _, ...rest } = config.models;
        return {
            ...config,
            models: rest,
        };
    });
}

async function isModelLoaded(modelName: ModelName): Promise<boolean> {
    const config = await readConfig();
    return !!config.models[modelName];
}

async function downloadLargeFile(url: string): Promise<FetchBlobResponse> {
    const isDirExists = await ReactNativeBlobUtil.fs.exists(TARGET_DIR);
    if (!isDirExists) {
        await ReactNativeBlobUtil.fs.mkdir(TARGET_DIR);
    }

    const filename = url.split('/').pop()

    return ReactNativeBlobUtil
        .config({
            path: `${TARGET_DIR}/${filename}`,
            fileCache: true,  // enables file caching
        })
        .fetch('GET', url, {
            // some headers ..
        })
    // .then((res) => {
    //   return res;
    // })
}

function extractRelativePath(fullPath: string) {
    const marker = "/Documents/";
    const index = fullPath.indexOf(marker);

    if (index === -1) {
        throw new Error("'/Documents/' not found in the path");
    }

    return fullPath.substring(index + marker.length);

};

export async function loadModel(modelName: ModelName) {
    const fileRegistryLocation = "https://registry.wfloat.com/repository/files/models/"
    if (modelName === "default_male" || modelName === "en_US-ryan-medium") {
        const isLoaded = await isModelLoaded(modelName)
        if (!isLoaded) {
            const configRes = await downloadLargeFile(`${fileRegistryLocation}/${modelName}.onnx.json`)
            const modelRes = await downloadLargeFile(`${fileRegistryLocation}/${modelName}.onnx`)
            await updateLoadedModelEntry({
                id: modelName,
                configPath: extractRelativePath(configRes.path()),
                modelPath: extractRelativePath(modelRes.path()),
                version: 0,
            });
        }
    } else if (!modelName) {
        throw new Error("Voice modelName is required.");
    } else {
        throw new Error(`Invalid voice modelName: ${modelName}.`);
    }
}

export async function unloadModel(modelName: ModelName) {
    if (modelName === "default_male" || modelName === "en_US-ryan-medium") {
        const isLoaded = await isModelLoaded(modelName)
        if (isLoaded) {
            const config = await readConfig();
            const modelConfigEntry = config.models[modelName]!;
            ReactNativeBlobUtil.fs.unlink(modelConfigEntry.configPath)
            ReactNativeBlobUtil.fs.unlink(modelConfigEntry.modelPath)
            await removeLoadedModelEntry(modelName)
        }
    } else if (!modelName) {
        throw new Error("Voice modelName is required.");
    } else {
        throw new Error(`Invalid voice modelName: ${modelName}.`);
    }
}

export async function PushAudioOutput(outputPath: string) {
    await modifyConfig(config => {
        return {
            ...config,
            outputs: [...config.outputs, outputPath],
        };
    });
}

export async function enforceAudioOutputLimit() {
    await modifyConfig(config => {
        if (config.outputs.length > AUDIO_OUTPUT_SAVE_LIMIT) {
            ReactNativeBlobUtil.fs.unlink(config.outputs[0]!)
            const newOutputs = config.outputs.slice(1);
            return {
                ...config,
                outputs: newOutputs,
            };
        }
        return config;
    });
}

export async function testStorage() {
    // await ReactNativeBlobUtil.fs.unlink(CONFIG_FILE_PATH)
    // await unloadModel("default_male");
    // // ReactNativeBlobUtil.fs.unlink(CONFIG_FILE_PATH)
    // console.log("config here", await readConfig())
    // await loadModel("default_male");
    // console.log("config updated", await readConfig())
}
