import ReactNativeBlobUtil, { type FetchBlobResponse } from 'react-native-blob-util';
import type { ModelName } from '.';

export const TARGET_DIR = `${ReactNativeBlobUtil.fs.dirs.DocumentDir}/react_native_wfloat`;
export const CONFIG_FILE_PATH = `${TARGET_DIR}/models_config.json`;
let operationQueue = Promise.resolve(); // Ensures sequential execution

async function readConfig(): Promise<ModelsConfig> {
    try {
        const exists = await ReactNativeBlobUtil.fs.exists(CONFIG_FILE_PATH);
        if (!exists) {
            await ReactNativeBlobUtil.fs.writeFile(CONFIG_FILE_PATH, JSON.stringify({}), 'utf8');
            return {};
        };

        const content = await ReactNativeBlobUtil.fs.readFile(CONFIG_FILE_PATH, 'utf8');
        return JSON.parse(content);
    } catch (error) {
        console.error("Error reading config:", error);
        return {};
    }
}

async function writeConfig(updatedConfig: ModelsConfig) {
    try {
        const jsonString = JSON.stringify(updatedConfig, null, 2);
        await ReactNativeBlobUtil.fs.writeFile(CONFIG_FILE_PATH, jsonString, 'utf8');
    } catch (error) {
        console.error("Error writing config:", error);
    }
}

async function modifyConfig(modifierFn: (config: ModelsConfig) => ModelsConfig) {
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
type ModelsConfig = Record<string, ModelConfigEntry>;

async function updateLoadedModelEntry(modelConfigEntry: ModelConfigEntry) {
    await modifyConfig(config => {
        return {
            ...config,
            [modelConfigEntry.id]: modelConfigEntry,
        };
    });
}

async function removeLoadedModelEntry(modelName: ModelName) {
    await modifyConfig(config => {
        const { [modelName]: _, ...rest } = config;
        return rest;
    });
}

async function isModelLoaded(modelName: ModelName): Promise<boolean> {
    const config = await readConfig();
    return !!config[modelName];
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

export async function loadModel(modelName: ModelName) {
    const fileRegistryLocation = "https://registry.wfloat.com/repository/files/models/"
    if (modelName === "default_male") {
        const isLoaded = await isModelLoaded("default_male")
        if (isLoaded) {
            console.log("model is loaded so nothing was downloaded")
        }
        if (!isLoaded) {
            const configRes = await downloadLargeFile(`${fileRegistryLocation}/default_male.onnx.json`)
            const modelRes = await downloadLargeFile(`${fileRegistryLocation}/default_male.onnx`)
            await updateLoadedModelEntry({
                id: "default_male",
                configPath: configRes.path(),
                modelPath: modelRes.path(),
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
    if (modelName === "default_male") {
        const isLoaded = await isModelLoaded("default_male")
        if (isLoaded) {
            const config = await readConfig();
            const modelConfigEntry = config[modelName]!;
            ReactNativeBlobUtil.fs.unlink(modelConfigEntry.configPath)
            ReactNativeBlobUtil.fs.unlink(modelConfigEntry.modelPath)
            await removeLoadedModelEntry("default_male")
        }
    } else if (!modelName) {
        throw new Error("Voice modelName is required.");
    } else {
        throw new Error(`Invalid voice modelName: ${modelName}.`);
    }
}

export async function testStorage() {
    // await unloadModel("default_male");
    // ReactNativeBlobUtil.fs.unlink(CONFIG_FILE_PATH)
    console.log("config here", await readConfig())
    await loadModel("default_male");
    console.log("config updated", await readConfig())
}
