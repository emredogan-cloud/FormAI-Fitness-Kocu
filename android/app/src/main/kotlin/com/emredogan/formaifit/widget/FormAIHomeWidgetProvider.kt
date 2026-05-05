// Phase 55 · Android home-screen widget provider.
//
// This is the Kotlin counterpart of `ios/FormAIWidget/FormAIWidget.swift`.
// The Flutter `home_widget` package writes its keys into a private
// `SharedPreferences("HomeWidgetPreferences", MODE_PRIVATE)` store and
// rings the OS update broadcast — this provider's `onUpdate` is what
// the OS calls in response. We read the same keys produced by
// `WidgetSyncService.push(...)` in
// `lib/core/services/widget_sync_service.dart`, paint them into the
// XML layout under `res/layout/form_ai_widget.xml`, and attach a
// PendingIntent so a tap deep-links into the live workout session.

package com.emredogan.formaifit.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import com.emredogan.formaifit.R
import es.antonborri.home_widget.HomeWidgetPlugin

class FormAIHomeWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val taskName = prefs.getString(KEY_TASK_NAME, "Hazır mısın?")
            ?: "Hazır mısın?"
        val subtitle = prefs.getString(KEY_SUBTITLE, "Antrenmanı başlat")
            ?: "Antrenmanı başlat"
        val progressPct = prefs.getInt(KEY_PROGRESS_PCT, 0)
        val streak = prefs.getInt(KEY_STREAK, 0)
        val completed = prefs.getInt(KEY_COMPLETED_DAYS, 0)
        val total = prefs.getInt(KEY_TOTAL_DAYS, 30)
        val deepLink = prefs.getString(KEY_DEEP_LINK, "formai://workout/today")
            ?: "formai://workout/today"

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.form_ai_widget)
            views.setTextViewText(R.id.widget_task_name, taskName)
            views.setTextViewText(R.id.widget_subtitle, subtitle)
            views.setTextViewText(R.id.widget_percent, "%$progressPct")
            views.setProgressBar(R.id.widget_progress, 100, progressPct, false)
            views.setTextViewText(R.id.widget_streak, "🔥 $streak")
            views.setTextViewText(
                R.id.widget_completion,
                "$completed / $total"
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                buildLaunchPendingIntent(context, id, deepLink)
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    /// Deep-link click target. We route through ACTION_VIEW with the
    /// `formai://` scheme so the same `DeepLinkService` listener that
    /// handles share-link redirection picks up the widget tap.
    ///
    /// Phase 55B · `FLAG_IMMUTABLE` is now unconditional. Android 12
    /// (API 31) requires every PendingIntent to declare either
    /// MUTABLE or IMMUTABLE — omitting both throws
    /// `IllegalArgumentException: Targeting S+ (version 31 and above)
    /// requires that one of FLAG_IMMUTABLE or FLAG_MUTABLE be specified
    /// when creating a PendingIntent`. The previous SDK_INT >= M guard
    /// covered older devices but the runtime API gate on S+ made the
    /// guard a footgun on modern phones, which is exactly what the PM
    /// hit. `FLAG_IMMUTABLE` itself shipped in API 23 (Marshmallow);
    /// our app's minSdk (24) is above that, so dropping the conditional
    /// is safe on every supported device.
    private fun buildLaunchPendingIntent(
        context: Context,
        widgetId: Int,
        deepLink: String
    ): PendingIntent {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLink))
        intent.setPackage(context.packageName)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(context, widgetId, intent, flags)
    }

    /// Force-refresh helper used by Flutter when it explicitly rings
    /// the update hook through `home_widget`. Not strictly required by
    /// the public AppWidgetProvider API but useful for unit tests
    /// that build a provider in isolation.
    fun refresh(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(
            ComponentName(context, FormAIHomeWidgetProvider::class.java)
        )
        onUpdate(context, mgr, ids)
    }

    companion object {
        // Mirrored verbatim from
        // lib/core/services/widget_sync_service.dart. Keep in sync.
        const val KEY_TASK_NAME = "today_task_name"
        const val KEY_SUBTITLE = "today_task_subtitle"
        const val KEY_PROGRESS_PCT = "progress_percent"
        const val KEY_STREAK = "streak_count"
        const val KEY_COMPLETED_DAYS = "completed_days"
        const val KEY_TOTAL_DAYS = "total_days"
        const val KEY_DEEP_LINK = "deep_link"
    }
}
