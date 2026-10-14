.pragma library

// Generated from AetherStudy_工具分类体系表.xlsx. Keep the workbook as the
// source of truth when the taxonomy changes.
var categoryTree = [{"name":"系统与运行时","children":[{"name":"交互与界面","toolIds":["browser","canvas","message"]},{"name":"会话与多智能体","toolIds":["agents_list","session_status","sessions_history","sessions_list","sessions_send","sessions_spawn","sessions_yield","subagents"]},{"name":"命令与进程","toolIds":["exec","process"]},{"name":"文件读写","toolIds":["apply_patch","edit","read","write"]},{"name":"编排与运行时","toolIds":["llm-task","lobster"]},{"name":"记忆与上下文","toolIds":["memory_get","memory_search","memory_forget","memory_recall","memory_store"]},{"name":"调度与网关","toolIds":["cron","gateway","nodes"]}]},{"name":"信息检索与文献","children":[{"name":"事实核查","toolIds":["fact_check_cache"]},{"name":"学术文献检索","toolIds":["med_intel_search_pubmed","mi_search_pubmed","citation_trace","pubmed_fetch","pubmed_search","semantic_scholar_search"]},{"name":"网页搜索与抓取","toolIds":["med_intel_fetch_url","mip_fetch_url","tavily_extract","tavily_search","web_fetch","web_search"]},{"name":"网页检索","toolIds":["firecrawl_scrape","firecrawl_search"]}]},{"name":"知识库与引用","children":[{"name":"引用与证据台账","toolIds":["references_pool_add","evidence_log","mip_cite"]},{"name":"知识库操作","toolIds":["kb_ingest","kb_manage","kb_search"]}]},{"name":"文档与格式转换","children":[{"name":"公文与研报生成","toolIds":["docx_add_comment","docx_fonts","docx_generate","report_assemble"]},{"name":"压缩包处理","toolIds":["file_extract","file_list_archive"]},{"name":"参考文献格式化","toolIds":["references_format"]},{"name":"文档格式转换","toolIds":["convert_document","pandoc_convert","pandoc_formats"]},{"name":"模板抽取与渲染","toolIds":["html_inline_assets","html_template_extract","html_template_render","template_extract","template_spec_extract"]},{"name":"结构化装配与校验","toolIds":["journal_assemble","journal_compliance_check"]}]},{"name":"可视化与多媒体","children":[{"name":"ECharts 交互图表","toolIds":["echarts_inline","echarts_render","echarts_transform"]},{"name":"多模态生成","toolIds":["image","image_generate","tts"]},{"name":"差异查看与渲染","toolIds":["diffs"]},{"name":"语音与通话","toolIds":["voice_call"]},{"name":"静态图表图片","toolIds":["png_chart","png_normalize"]}]},{"name":"数据分析与统计","children":[{"name":"代码执行","toolIds":["data_execute_code"]},{"name":"回归分析","toolIds":["stats_linear_regression","stats_logistic_regression"]},{"name":"描述性统计","toolIds":["period_compare","stats_comparative","stats_crosstab","stats_tableone"]},{"name":"数据清洗与准备","toolIds":["data_clean","mi_prepare_data"]},{"name":"数据读取与画像","toolIds":["data_explore","data_profile","mi_read_internal_file","read_file_content"]},{"name":"相关与关联分析","toolIds":["stats_association","stats_correlation"]}]},{"name":"机器学习与建模","children":[{"name":"建模流水线","toolIds":["mi_run_model","ml_run_pipeline"]},{"name":"模型评估与导出","toolIds":["ml_export_model","ml_recommend_models","model_explain"]}]},{"name":"组学分析","children":[{"name":"Bulk RNA-seq","toolIds":["bulkrna_batch_correction","bulkrna_coexpression","bulkrna_de","bulkrna_deconvolution","bulkrna_enrichment","bulkrna_geneid_mapping","bulkrna_ppi_network","bulkrna_qc","bulkrna_read_alignment","bulkrna_read_qc","bulkrna_splicing","bulkrna_survival","bulkrna_trajblend"]},{"name":"代谢组","toolIds":["metabolomics_annotation","metabolomics_differential","metabolomics_normalization","metabolomics_pathway_enrichment","metabolomics_peak_detection","metabolomics_quantification","metabolomics_statistics","metabolomics_xcms_preprocessing"]},{"name":"单细胞转录组","toolIds":["scrna_annotate","scrna_cluster","scrna_preprocess","scrna_validate"]},{"name":"基因组学","toolIds":["genomics_alignment","genomics_assembly","genomics_cnv_calling","genomics_epigenomics","genomics_phasing","genomics_read_qc","genomics_sv_detection","genomics_variant_annotation","genomics_variant_calling","genomics_vcf_operations"]},{"name":"多组学整合","toolIds":["omics_integrate"]},{"name":"空间转录组","toolIds":["spatial_cluster","spatial_deg","spatial_enrichment","spatial_load","spatial_qc"]},{"name":"蛋白质组","toolIds":["proteomics_data_import","proteomics_differential_abundance","proteomics_identification","proteomics_ms_qc","proteomics_pathway_enrichment","proteomics_ptm_analysis","proteomics_quantification","proteomics_structural"]}]},{"name":"医学影像处理","children":[{"name":"DICOM 基础","toolIds":["imaging_dicom_anonymize","imaging_dicom_decompress","imaging_dicom_inspect","imaging_dicom_multiframe","imaging_dicom_to_nifti"]},{"name":"影像质控","toolIds":["imaging_mask_qc","imaging_nifti_io_qc","imaging_seg_dl"]},{"name":"特征与报告","toolIds":["imaging_case","imaging_radiomics","imaging_report_extract","imaging_xray_io"]},{"name":"解剖分割","toolIds":["imaging_seg_classic","imaging_seg_radar"]},{"name":"预处理与配准","toolIds":["imaging_preprocess","imaging_register"]}]},{"name":"医学情报","children":[{"name":"中间结论沉淀","toolIds":["mi_save_analysis","mi_save_competitor_analysis","mi_save_insights","mi_save_kol_analysis","mi_save_kol_candidates","mi_save_kol_map","mi_save_kol_scores","mi_save_model_results","mi_save_search_log","mi_save_training_content","mip_save_analysis"]},{"name":"威胁评估与评分","toolIds":["med_intel_threat_score","med_intel_threat_summary","threat_score","threat_score_summary"]},{"name":"审核与阶段校验","toolIds":["mi_medical_review","mi_search_rwe","mi_verify_phase","mip_review_finding","mip_verify_phase"]},{"name":"情报采集","toolIds":["med_intel_search_regulatory","med_intel_search_trials","mi_ai_reviewer","mi_lookup_kol","mi_search_hta","mi_search_regulatory","mi_search_safety_signals","mi_search_trials","mip_search_clinicaltrials","mip_search_openfda"]},{"name":"报告与交付物","toolIds":["med_intel_generate_report","med_intel_save_card","mi_draft_mir_response","mi_generate_executive_digest","mi_generate_slides","mi_list_pptx_layouts","mi_prepare_pptx_template"]},{"name":"文献筛选与证据提取","toolIds":["cer_appraise_quality","cer_extract_data","cer_screen_literature","mi_extract_evidence","mi_normalize_dedupe","mi_screen_literature"]},{"name":"目标池与监测台账","toolIds":["med_intel_target_config","med_intel_target_read","mi_list_monitors","mi_load_monitor","mi_save_monitor_snapshot","target_config"]},{"name":"计划与阶段规则","toolIds":["mi_get_phase_rules","mi_get_report_template","mi_get_step_instruction","mi_save_plan","mi_start_report","mip_get_phase_rules","mip_get_step_instruction","mip_save_plan","mip_start_report"]}]}];

var uncategorizedPrimary = "未分类"
var uncategorizedSecondary = "其他工具"
var _categoryByToolId = null
var _knownToolIds = null

function _ensureIndex() {
    if (_categoryByToolId !== null)
        return

    _categoryByToolId = ({})
    _knownToolIds = []
    for (var primaryIndex = 0; primaryIndex < categoryTree.length; primaryIndex++) {
        var primary = categoryTree[primaryIndex]
        for (var secondaryIndex = 0; secondaryIndex < primary.children.length; secondaryIndex++) {
            var secondary = primary.children[secondaryIndex]
            for (var toolIndex = 0; toolIndex < secondary.toolIds.length; toolIndex++) {
                var toolId = String(secondary.toolIds[toolIndex]).trim().toLowerCase()
                _categoryByToolId[toolId] = {
                    primary: primary.name,
                    secondary: secondary.name
                }
                _knownToolIds.push(toolId)
            }
        }
    }

    // Prefer the most specific suffix when a catalog returns namespaced IDs.
    _knownToolIds.sort(function(left, right) { return right.length - left.length })
}

function classify(toolId) {
    _ensureIndex()
    var normalizedId = String(toolId || "").trim().toLowerCase()
    if (_categoryByToolId[normalizedId])
        return _categoryByToolId[normalizedId]

    for (var index = 0; index < _knownToolIds.length; index++) {
        var knownId = _knownToolIds[index]
        if (normalizedId.length > knownId.length
                && normalizedId.lastIndexOf(knownId) === normalizedId.length - knownId.length)
            return _categoryByToolId[knownId]
    }

    return {
        primary: uncategorizedPrimary,
        secondary: uncategorizedSecondary
    }
}
