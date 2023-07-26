import 'dart:io';

import 'package:cw_core/pathForWallet.dart';
import 'package:cw_core/wallet_base.dart';
import 'package:cw_core/wallet_credentials.dart';
import 'package:cw_core/wallet_info.dart';
import 'package:cw_core/wallet_service.dart';
import 'package:cw_core/wallet_type.dart';
import 'package:cw_nano/nano_mnemonic.dart';
// import 'package:cw_nano/nano_mnemonics.dart';
import 'package:cw_nano/nano_wallet.dart';
import 'package:cw_nano/nano_wallet_creation_credentials.dart';
import 'package:hive/hive.dart';
import 'package:bip39/bip39.dart' as bip39;

class NanoNewWalletCredentials extends WalletCredentials {
  NanoNewWalletCredentials({required String name, String? password})
      : super(name: name, password: password);
}

class NanoRestoreWalletFromSeedCredentials extends WalletCredentials {
  NanoRestoreWalletFromSeedCredentials(
      {required String name,
      required this.mnemonic,
      required this.derivationType,
      int height = 0,
      String? password})
      : super(name: name, password: password, height: height);

  final String mnemonic;
  final DerivationType derivationType;
}

class NanoWalletLoadingException implements Exception {
  @override
  String toString() => 'Failure to load the wallet.';
}

class NanoRestoreWalletFromKeysCredentials extends WalletCredentials {
  NanoRestoreWalletFromKeysCredentials(
      {required String name,
      required String password,
      required this.language,
      required this.address,
      required this.viewKey,
      required this.spendKey,
      int height = 0})
      : super(name: name, password: password, height: height);

  final String language;
  final String address;
  final String viewKey;
  final String spendKey;
}

class NanoWalletService extends WalletService<NanoNewWalletCredentials,
    NanoRestoreWalletFromSeedCredentials, NanoRestoreWalletFromKeysCredentials> {
  NanoWalletService(this.walletInfoSource);

  final Box<WalletInfo> walletInfoSource;

  static bool walletFilesExist(String path) =>
      !File(path).existsSync() && !File('$path.keys').existsSync();

  @override
  WalletType getType() => WalletType.nano;

  @override
  Future<WalletBase> create(NanoNewWalletCredentials credentials) async {
    print("nano_wallet_service create");
    final mnemonic = bip39.generateMnemonic();
    final wallet = NanoWallet(
      walletInfo: credentials.walletInfo!,
      mnemonic: mnemonic,
      password: credentials.password!,
      derivationType: DerivationType.bip39,
    );
    return wallet;
  }

  @override
  Future<void> remove(String wallet) async {
    final path = await pathForWalletDir(name: wallet, type: getType());
    final file = Directory(path);
    final isExist = file.existsSync();

    if (isExist) {
      await file.delete(recursive: true);
    }

    final walletInfo = walletInfoSource.values
        .firstWhere((info) => info.id == WalletBase.idFor(wallet, getType()));
    await walletInfoSource.delete(walletInfo.key);
  }

  @override
  Future<void> rename(String currentName, String password, String newName) async {
    // final currentWalletInfo = walletInfoSource.values
    //     .firstWhere((info) => info.id == WalletBase.idFor(currentName, getType()));
    // final currentWallet = NanoWallet(walletInfo: currentWalletInfo);

    // await currentWallet.renameWalletFiles(newName);

    // final newWalletInfo = currentWalletInfo;
    // newWalletInfo.id = WalletBase.idFor(newName, getType());
    // newWalletInfo.name = newName;

    // await walletInfoSource.put(currentWalletInfo.key, newWalletInfo);
  }

  @override
  Future<NanoWallet> restoreFromKeys(NanoRestoreWalletFromKeysCredentials credentials) async {
    print("a");
    throw UnimplementedError();
    // try {
    //   final path = await pathForWallet(name: credentials.name, type: getType());
    //   await monero_wallet_manager.restoreFromKeys(
    //       path: path,
    //       password: credentials.password!,
    //       language: credentials.language,
    //       restoreHeight: credentials.height!,
    //       address: credentials.address,
    //       viewKey: credentials.viewKey,
    //       spendKey: credentials.spendKey);
    //   final wallet = NanoWallet(walletInfo: credentials.walletInfo!);
    //   await wallet.init();

    //   return wallet;
    // } catch (e) {
    //   // TODO: Implement Exception for wallet list service.
    //   print('NanoWalletsManager Error: $e');
    //   rethrow;
    // }
  }

  Future<DerivationType> compareDerivationMethods({String? mnemonic, String? seedKey}) async {
    return DerivationType.nano;
  }

  @override
  Future<NanoWallet> restoreFromSeed(NanoRestoreWalletFromSeedCredentials credentials) async {
    if (!bip39.validateMnemonic(credentials.mnemonic)) {
      throw NanoMnemonicIsIncorrectException();
    }

    if (!NanoMnemomics.validateMnemonic(credentials.mnemonic.split(' '))) {
      throw NanoMnemonicIsIncorrectException();
    }

    DerivationType derivationType = DerivationType.bip39;

    if (credentials.mnemonic.split(' ').length == 12) {
      derivationType = DerivationType.bip39;
    } else {
      // we don't know for sure, but probably the nano standard:
      derivationType = await compareDerivationMethods(mnemonic: credentials.mnemonic);
    }

    final wallet = await NanoWallet(
      password: credentials.password!,
      mnemonic: credentials.mnemonic,
      walletInfo: credentials.walletInfo!,
      derivationType: derivationType,
    );

    try {
      await wallet.init();
    } catch (e) {
      print("test");
      print(e);
      rethrow;
    }
    await wallet.save();
    return wallet;
  }

  @override
  Future<bool> isWalletExit(String name) async =>
      File(await pathForWallet(name: name, type: getType())).existsSync();

  @override
  Future<NanoWallet> openWallet(String name, String password) async {
    final walletInfo =
        walletInfoSource.values.firstWhere((info) => info.id == WalletBase.idFor(name, getType()));
    final wallet = await NanoWalletBase.open(
      name: name,
      password: password,
      walletInfo: walletInfo,
    );

    await wallet.init();
    await wallet.save();
    return wallet;
  }
}
