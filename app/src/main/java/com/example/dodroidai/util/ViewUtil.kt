package com.mohanlv.common

import android.content.Context
import android.content.res.Resources
import android.view.View
import android.view.ViewGroup
import androidx.annotation.Px
import androidx.fragment.app.Fragment
import com.mohanlv.base.utils.AppUtils

fun Fragment.getSafeContext(): Context {
    return context ?: AppUtils.getContext()
}

fun View.updateMarginTop(@Px top: Int) {
    val lp = this.layoutParams as? ViewGroup.MarginLayoutParams
    lp?.topMargin = top
    this.layoutParams = lp
}

fun View.updateMarginBottom(@Px bottom: Int) {
    val lp = this.layoutParams as? ViewGroup.MarginLayoutParams
    lp?.bottomMargin = bottom
    this.layoutParams = lp
}

fun View.updateMarginLeft(@Px left: Int) {
    val lp = this.layoutParams as? ViewGroup.MarginLayoutParams
    lp?.leftMargin = left
    this.layoutParams = lp
}

fun View.updateMarginRight(@Px right: Int) {
    val lp = this.layoutParams as? ViewGroup.MarginLayoutParams
    lp?.rightMargin = right
    this.layoutParams = lp
}

fun dp2px(dp: Float): Float {
    return dp * Resources.getSystem().displayMetrics.density
}

val Float.dpFloat: Float get() = dp2px(this)

val Float.dp: Int get() = this.dpFloat.toInt()

val Int.dp: Int get() = this.toFloat().dpFloat.toInt()

val Int.dpFloat: Float get() = this.toFloat().dpFloat

fun ViewGroup.safeAddView(view: View?, position: Int = -1) {
    if (view == null) return
    if (view.parent != null) {
        (view.parent as? ViewGroup)?.removeView(view)
    }
    if (position < 0) {
        addView(view)
    } else {
        addView(view, position)
    }
}
