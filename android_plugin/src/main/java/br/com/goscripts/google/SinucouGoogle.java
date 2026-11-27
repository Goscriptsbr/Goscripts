package br.com.goscripts.google;

import android.app.Activity;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.Signature;
import java.security.MessageDigest;
import android.os.CancellationSignal;

import androidx.annotation.NonNull;
import androidx.credentials.Credential;
import androidx.credentials.CredentialManager;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.CustomCredential;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.exceptions.GetCredentialCancellationException;
import androidx.credentials.exceptions.GetCredentialException;

import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption;
import com.google.android.play.core.appupdate.AppUpdateInfo;
import com.google.android.play.core.appupdate.AppUpdateManager;
import com.google.android.play.core.appupdate.AppUpdateManagerFactory;
import com.google.android.play.core.appupdate.AppUpdateOptions;
import com.google.android.play.core.install.model.AppUpdateType;
import com.google.android.play.core.install.model.UpdateAvailability;
import android.content.Intent;
import android.net.Uri;
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.Executors;

/** Entrar com Google pela janelinha do próprio Android (Credential Manager). */
public class SinucouGoogle extends GodotPlugin {
    public SinucouGoogle(Godot godot) { super(godot); }

    @NonNull @Override
    public String getPluginName() { return "SinucouGoogle"; }

    @NonNull @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> s = new HashSet<>();
        s.add(new SignalInfo("google_ok", String.class, String.class));
        s.add(new SignalInfo("google_fail", String.class, String.class));
        s.add(new SignalInfo("update_info", Integer.class, Integer.class));
        return s;
    }

    // SHA-1 do certificado que assinou este app (para o servidor saber se o jogo foi modificado)
    @UsedByGodot
    public String sigHash() {
        try {
            Activity a = getActivity();
            if (a == null) return "";
            PackageManager pm = a.getPackageManager();
            Signature[] sigs;
            if (android.os.Build.VERSION.SDK_INT >= 28) {
                PackageInfo pi = pm.getPackageInfo(a.getPackageName(), PackageManager.GET_SIGNING_CERTIFICATES);
                sigs = pi.signingInfo.hasMultipleSigners() ? pi.signingInfo.getApkContentsSigners() : pi.signingInfo.getSigningCertificateHistory();
            } else {
                PackageInfo pi = pm.getPackageInfo(a.getPackageName(), PackageManager.GET_SIGNATURES);
                sigs = pi.signatures;
            }
            if (sigs == null || sigs.length == 0) return "";
            byte[] d = MessageDigest.getInstance("SHA-1").digest(sigs[sigs.length - 1].toByteArray());
            StringBuilder sb = new StringBuilder();
            for (byte b : d) { if (sb.length() > 0) sb.append(':'); sb.append(String.format("%02X", b)); }
            return sb.toString();
        } catch (Exception e) {
            return "";
        }
    }

    // ---------------- atualização pela Play Store (In-App Updates)
    // update_info(versionCode, status): status 0 = está em dia, 1 = tem versão nova, 2 = atualização já começou, -1 = erro/não instalado pela Play
    private AppUpdateManager upd;
    private AppUpdateInfo updInfo;

    private AppUpdateManager updMgr() {
        if (upd == null && getActivity() != null) upd = AppUpdateManagerFactory.create(getActivity());
        return upd;
    }

    @UsedByGodot
    public void checkUpdate() {
        final Activity act = getActivity();
        if (act == null) { emitSignal("update_info", 0, -1); return; }
        act.runOnUiThread(() -> {
            try {
                AppUpdateManager m = updMgr();
                m.getAppUpdateInfo().addOnSuccessListener(info -> {
                    updInfo = info;
                    int a = info.updateAvailability();
                    int st = 0;
                    if (a == UpdateAvailability.UPDATE_AVAILABLE) st = 1;
                    else if (a == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS) st = 2;
                    emitSignal("update_info", info.availableVersionCode(), st);
                }).addOnFailureListener(e -> emitSignal("update_info", 0, -1));
            } catch (Throwable t) {
                emitSignal("update_info", 0, -1);
            }
        });
    }

    // abre a tela de atualização da própria Play Store (baixa, instala e reabre o jogo sozinha)
    @UsedByGodot
    public void startUpdate() {
        final Activity act = getActivity();
        if (act == null) return;
        act.runOnUiThread(() -> {
            try {
                AppUpdateManager m = updMgr();
                if (updInfo != null && (updInfo.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                        || updInfo.updateAvailability() == UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS)
                        && updInfo.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE)) {
                    m.startUpdateFlowForResult(updInfo, act, AppUpdateOptions.defaultOptions(AppUpdateType.IMMEDIATE), 7101);
                    return;
                }
            } catch (Throwable t) { /* cai para a página da loja */ }
            openStore();
        });
    }

    @UsedByGodot
    public void openStore() {
        final Activity act = getActivity();
        if (act == null) return;
        String pkg = act.getPackageName();
        try {
            act.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=" + pkg)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (Throwable t) {
            act.startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=" + pkg)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        }
    }

    @UsedByGodot
    public void signIn(String webClientId) {
        final Activity act = getActivity();
        if (act == null) { emitSignal("google_fail", "erro", "sem activity"); return; }
        act.runOnUiThread(() -> {
            try {
                GetSignInWithGoogleOption opt = new GetSignInWithGoogleOption.Builder(webClientId).build();
                GetCredentialRequest req = new GetCredentialRequest.Builder().addCredentialOption(opt).build();
                CredentialManager cm = CredentialManager.create(act);
                cm.getCredentialAsync(act, req, new CancellationSignal(), Executors.newSingleThreadExecutor(),
                    new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                        @Override
                        public void onResult(GetCredentialResponse res) {
                            Credential c = res.getCredential();
                            if (c instanceof CustomCredential && GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL.equals(c.getType())) {
                                try {
                                    GoogleIdTokenCredential g = GoogleIdTokenCredential.createFrom(c.getData());
                                    emitSignal("google_ok", g.getIdToken(), g.getId());
                                } catch (Exception e) {
                                    emitSignal("google_fail", "erro", String.valueOf(e.getMessage()));
                                }
                            } else {
                                emitSignal("google_fail", "erro", "tipo de credencial inesperado");
                            }
                        }

                        @Override
                        public void onError(GetCredentialException e) {
                            String kind = (e instanceof GetCredentialCancellationException) ? "cancelado" : "erro";
                            emitSignal("google_fail", kind, e.getClass().getSimpleName() + ": " + e.getMessage());
                        }
                    });
            } catch (Throwable t) {
                emitSignal("google_fail", "erro", String.valueOf(t.getMessage()));
            }
        });
    }
}
