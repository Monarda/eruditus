import 'package:eruditus/data/datasources/asset_data_loader.dart';
import 'package:eruditus/data/datasources/local_configuration_datasource.dart';
import 'package:eruditus/models/base_effect.dart';
import 'package:eruditus/models/parameter.dart';
import 'package:eruditus/models/special_factor.dart';

class ConfigurationRepository {
  final AssetDataLoader assetLoader;
  final LocalConfigurationDatasource configDatasource;

  ConfigurationRepository({required this.assetLoader, required this.configDatasource});

  Future<List<BaseEffect>> getAllEffects() async {
    final builtIn = await assetLoader.loadBaseEffects();
    final custom = await configDatasource.getAllCustomEffects();
    return [...builtIn, ...custom];
  }

  Future<List<Parameter>> getAllParameters() async {
    final builtIn = await assetLoader.loadParameters();
    final custom = await configDatasource.getAllCustomParameters();
    return [...builtIn, ...custom];
  }

  Future<List<SpecialFactor>> getAllSpecialFactors() async {
    final builtIn = await assetLoader.loadSpecialFactors();
    final custom = await configDatasource.getAllCustomFactors();
    return [...builtIn, ...custom];
  }

  Future<void> addCustomEffect(BaseEffect effect) => configDatasource.insertCustomEffect(effect);
  Future<void> deleteCustomEffect(String id) => configDatasource.deleteCustomEffect(id);

  Future<void> addCustomParameter(Parameter parameter) => configDatasource.insertCustomParameter(parameter);
  Future<void> deleteCustomParameter(String id) => configDatasource.deleteCustomParameter(id);

  Future<void> addCustomFactor(SpecialFactor factor) => configDatasource.insertCustomFactor(factor);
  Future<void> deleteCustomFactor(String id) => configDatasource.deleteCustomFactor(id);
}
