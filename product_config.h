#ifndef PRODUCT_CONFIG_H
#define PRODUCT_CONFIG_H

#include <QString>

namespace ProductConfig {

inline bool isBusiness()
{
#ifdef MEDCLAW_PRODUCT_B
    return true;
#else
    return false;
#endif
}

inline bool isInternalNetwork()
{
#ifdef MEDCLAW_NETWORK_INTERNAL
    return true;
#else
    return false;
#endif
}

// Content edition, independent of the product type: the imaging UI ships both
// as B (tenant_imaging) and as C (product_c edition_imaging).
inline bool isImagingEdition()
{
#ifdef MEDCLAW_EDITION_IMAGING
    return true;
#else
    return false;
#endif
}

inline QString tenantCode()
{
#ifdef MEDCLAW_TENANT_GOVERNMENT
    return QStringLiteral("gov-01");
#elif defined(MEDCLAW_TENANT_IMAGING)
    return QStringLiteral("image-01");
#elif defined(MEDCLAW_TENANT_HOSPITAL_CHANG2)
    return QStringLiteral("hospital-chang2");
#else
    return QString();
#endif
}

inline QString tenantKey()
{
#ifdef MEDCLAW_TENANT_GOVERNMENT
    return QStringLiteral("government");
#elif defined(MEDCLAW_TENANT_IMAGING)
    return QStringLiteral("imaging");
#elif defined(MEDCLAW_TENANT_HOSPITAL_CHANG2)
    return QStringLiteral("hospital-chang2");
#else
    return QStringLiteral("consumer");
#endif
}

inline QString tenantDisplayName()
{
#ifdef MEDCLAW_TENANT_GOVERNMENT
    return QStringLiteral("政务");
#elif defined(MEDCLAW_TENANT_IMAGING)
    return QStringLiteral("影像");
#elif defined(MEDCLAW_TENANT_HOSPITAL_CHANG2)
    return QStringLiteral("长二医院");
#else
    return QString();
#endif
}

inline QString updateAppKey()
{
#ifdef MEDCLAW_TENANT_HOSPITAL_CHANG2
    return QStringLiteral("hospital-chang2");
#else
    return QStringLiteral("aether-study");
#endif
}

inline QString updateVersionSuffix()
{
#ifdef MEDCLAW_TENANT_GOVERNMENT
    return QStringLiteral("-gov");
#elif defined(MEDCLAW_TENANT_HOSPITAL_CHANG2)
    return QStringLiteral("-chang2");
#else
    // Imaging historically shared the unsuffixed public client version.
    return QString();
#endif
}

inline QString networkKey()
{
    return isInternalNetwork() ? QStringLiteral("internal") : QStringLiteral("public");
}

inline QString settingsOrganizationName()
{
    return QStringLiteral("AetherMED");
}

inline QString settingsApplicationName()
{
    if (!isBusiness())
        return QStringLiteral("Aether study");
    return QStringLiteral("Aether study B-%1-%2").arg(tenantKey(), networkKey());
}

inline QString dataDirectoryName()
{
    if (!isBusiness())
        return QStringLiteral("AetherStudy");
#if defined(MEDCLAW_TENANT_HOSPITAL_CHANG2) && defined(MEDCLAW_NETWORK_INTERNAL)
    // Keep existing Chang2 internal installations and their local data in place.
    return QStringLiteral("AetherStudy-hospital-chang2");
#elif defined(MEDCLAW_TENANT_IMAGING) && defined(MEDCLAW_NETWORK_PUBLIC)
    return QStringLiteral("AetherStudy-imaging");
#else
    return QStringLiteral("AetherStudy-B-%1-%2").arg(tenantKey(), networkKey());
#endif
}

inline QString workspaceRootRelativePath()
{
    if (!isBusiness())
        return QStringLiteral("AetherStudy/workspace");
#if defined(MEDCLAW_TENANT_HOSPITAL_CHANG2) && defined(MEDCLAW_NETWORK_INTERNAL)
    return QStringLiteral("hospital-chang2/workspace");
#else
    return QStringLiteral("AetherStudy-B-%1-%2/workspace").arg(tenantKey(), networkKey());
#endif
}

inline QString openClawWorkspaceDirectoryName()
{
    if (!isBusiness())
        return QStringLiteral("workspace");
#if defined(MEDCLAW_TENANT_HOSPITAL_CHANG2) && defined(MEDCLAW_NETWORK_INTERNAL)
    return QStringLiteral("workspace-hospital-chang2");
#else
    return QStringLiteral("workspace-b-%1-%2").arg(tenantKey(), networkKey());
#endif
}

} // namespace ProductConfig

#endif // PRODUCT_CONFIG_H
