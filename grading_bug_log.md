# 評分腳本 Bug 歷史與症狀速查

> **用途**：評分腳本（`_Scripts/grade_w*.Rmd` 與共用函式）的 Bug 記錄、症狀速查、修復歷史。
> **觸發**：當 `stats-grading-meta` skill 啟動時，Claude 會讀取本檔；開發/除錯評分腳本時可直接查閱。
> **維護**：新 Bug 確認並修復後，登記到本檔（不要加到 SKILL.md）；常見症狀同步更新症狀速查表。

---

## 一、症狀速查表

> ⚠️ **強制規則**：遇到任何評分異常，先查此表確認是否為已知問題，再開始 debug。

| 觀察到的症狀 | 可能根因 | Bug 表關鍵字 |
|:------------|:---------|:------------|
| CI_Width 提取到 Q3 內容（「如果你是研究者...」）| start_regex `CI.*寬度` 同時匹配 Q3 heading「縮小 CI 寬度的代價」；Task 2 heading 不是 heading-styled 時從 Q3 開始提取 | 「CI_Width 誤抓 Q3 標題（regex 跨節匹配）」 |
| `validate_omv_data()` 回傳 `valid=FALSE`，但欄位確實存在 | case-sensitive 比對 / 中文欄位名（如 `總分`） | 「欄位比對 case-sensitive」「中文別名」 |
| Fig2AutoScore=0，學生答案與期望值差 ≤1 整數 | Mdn/IQR 容差 0.1 對整數分數過嚴 | 「boxplot 容差過嚴」 |
| Figure1 自動評分偵測到「二、箱形圖」等模板文字 | heading 提取溢出至下一節 | 「Figure1_Caption 帶入模板」 |
| ManualTotal 超過 `manual_weight` 上限 | 舊格式 CSV 多題欄干擾加總 | 「ManualTotal 超出上限」 |
| StudentID 匹配結果 0/N（全失敗） | 前導零遺失（read.csv 自動轉數字） | 「StudentID 前導零」 |
| OMV 評分全 0，DOCX 分數正常 | 資料驗證失敗（示範資料或他人資料） | `validate_omv_data()` 設計節 |
| 複評後 `prep_omv_info` 仍扣命名分 | 複評 Prep Report 未優先讀取 | 「複評 prep_omv_info 誤用初評」 |
| Descriptives 圖表評分 0，OMV 確有圖 | 僅掃 Plots Tab，Descriptives 模組路徑未偵測 | 「Descriptives 模組製圖被評 0 分」 |
| symmetric 方向假陽性（常態模板文字觸發） | `理論常態分佈` 被 symmetric pattern 命中 | 「理論常態分佈觸發 symmetric 假陽性」 |
| 10 位學號被截斷為假 9 位學號 | `parse_student_id()` 只取前 9 位 | 「10位學號被截斷」 |
| Stage C 整合後 `匹配結果 0/N` | StudentID 格式不一致（補零時機） | 「StudentID 前導零」 |
| 複評回饋分發 pattern 找不到 `_Revision_Feedback.html` | distribute_feedback 正規式未含 `(_Revision)?` | 「distribute_feedback pattern bug」 |
| OMV 讀取 formula 評分全 0（如 Z 分數、公式變項偵測） | metadata 路徑錯誤（`$fields` 應為 `$dataSet$fields`）+ fromJSON 轉為 data.frame 需迭代列 | 「Z 分數偵測 metadata 路徑錯誤」 |
| 全班某題自動評分大量 0 分（> 70% 學生）| 評分標準可能過嚴或與報告模板結構不符 | 「Q1 Q-Q Plot 評分對新手過嚴」（考慮階層式新手保底）|
| Q2「不顯著」答案被誤判為 reject 給分 | `grepl("顯著", "不顯著")` 為 TRUE，無否定感知 | 「Q2 Shapiro-Wilk 顯著誤命中不顯著」 |
| Filter（篩選條件）公式被誤判為學生做的變項計算 | 未跳過 `columnType="filter"` 列 | 「Z 分數偵測 metadata 路徑錯誤」（跳過 Filter 區塊）|
| 複評 PngScore = 0，學生在 Revision/ 有上傳修正版 PNG | `prepare_revisions()` 未收集 PNG → Revisions/ 無 PNG | 「prepare_revisions 未收集 PNG」|
| 回饋顯示「△ PNG 解析度偏低（NA × NA px）」，PngScore 不為 0 | 學生上傳 JPEG 格式但副檔名為 .png（magic bytes FF D8）；`read_png_header()` 偵測為 valid=FALSE | 「PNG 實際 JPEG 格式」|
| SE 驗算自動評分全班 86% 得 0 分 | 作業模板讓學生填 SE 值而非 t 值；評分只查 t；df 容差 0.5 < N-df 差值 1.0 | 「SE 驗算評分只查 t 值」「df 容差過嚴」 |
| SE_Verify 章節提取到操作說明/URL（有效數字不足）| heading regex 命中非預期標題；改用全文 fallback | 「SE_Verify heading 提取錯誤」 |
| SE 比值 SD 數值評分為 0，學生確有填寫 | 學生將 jamovi 描述統計表貼入 Word 表格（table cells）；`extract_answers_by_headers()` 只讀 paragraph，完全遺漏 table cells | 「Word 表格 SD 值遺漏（table cell 提取）」|
| 直方圖 APA 標題數值評分為 0，學生 M/SD 四捨五入為整數 | tol=0.1 對整數舍入（最大誤差 0.499）過嚴；模板「範例：Figure 1. M=498.23, SD=98.45」污染數值池 | 「直方圖標題容差過嚴 + 模板範例污染」|
| 直方圖 APA 評分為 0，學生圖說置於子標題下 | 學生將 6 則圖說分別放在 heading 3 子標題（Pop_RT/Means_RT_N5...）下，且未用「Figure X.」格式；heading-based 提取截斷於第一個子標題，且掃描 Figure 字眼的 fallback 也找不到 | 「直方圖圖說置於子標題下（fallback 掃描失效）」|
| 有 DOCX 無 OMV 的學生完全被跳過（不進 grading_df 也沒 Manual Review） | `grade_word` 只迭代 `omv_files`；`docx_only_students` 在 export 之後才跑，為時已晚 → 學生被誤判為「未繳交」 | 「DOCX-only 學生完全被跳過」|
| W13+ APA_自動全班 0 分（模板無 heading style）| Strategy 2 start_pos 選到 📋 操作說明段落 → end=start → 提取空；或 marker 為最後元素 → 逆序序列污染 | 「start_pos 未過濾 📋」「marker 逆序序列」|
| 某題只提取到 section header（如「Q2: 預期次數」）而非學生答案 | `問題：...` 提示行含關鍵詞，被誤判為下一節 end boundary → Q2 端點 = Q2 起點 | 「問題提示段落誤判為節邊界」|
| W12 jpower_omv 全班 0 分 | `check_jpower()` 搜尋名為 "jpower" 的目錄；jamovi 實際嵌入 ttestIS/ttestPS 數字目錄 → 永遠找不到 | 「jpower OMV 偵測使用目錄名而非內容」|
| W12 jpower Word 全班 0 分（或有不合理假陽性 1.25 分）| `extract_section_content()` 只讀 paragraph；學生填表格 → text 為空；或 α=.05 條件文字與 d_input 容差內匹配 | 「jpower Word 評分遺漏表格欄位 + 條件文字假陽性」|
| W12 APA_Independent 自動評分 0 分（目視確認有填寫）| `Independent_Result` regex 含 `Score_T1.*比較`，命中 APA 段內子標題 → 章節提前截斷 | 「APA_Independent 章節提前截斷」|
| 學生寫「未達顯著水準」仍被判為 reject（給分）| `preprocess_sig_negation` 中 `未` 只匹配緊接「顯著」；「未達顯著」中有「達」字 | 「preprocess_sig_negation 不識別未達顯著」|
| W12 jpower Word 早停（前 5 名全 0 觸發 ITER_ZERO_STOP）| 模板 `&nbsp;` → U+00A0，`nzchar(trimws())` 返回 TRUE；且 4-2 section 溢出到「五、觀念辨析」→ had_text=TRUE 無數字 | 「jpower 4-2 section 溢出＋NBSP 假 had_text」|
| APA t 值為負但期望值為正，t 比對失敗 | `near_match` 不使用 abs(nums)；學生寫 t=-0.391，期望 0.391 → |−0.391−0.391|=0.782 > 0.1 | 「APA t 值帶符號匹配失敗」|
| 某節（如 APA_Paired）只提取格式範例行、缺學生回答文字 | Strategy 2 結束邊界過濾器只排除「我的回答：」，未排除「我的報告：」等同義標記；學生回答含節 regex 關鍵字 → 被誤判為下一節起點 → 章節提前截斷 | 「APA 回答標記誤判為節邊界」|
| Levene's Test 自動評分 0 分，學生 Word 中確有填寫診斷（且 jamovi 輸出表格存在） | `extract_answers_by_headers()` 只讀 `content_type=="paragraph"`；學生將診斷結果填入 Word 表格（table cells）→ `text_lev` 為空或只含模板文字 → 評分全 0 | 「Levene_Report table cell 遺漏（⚠️ 未修復，需手動更正）」|
| **複評回饋顯示「補交與修正規範」而非「本週 LAB 評量完成」**（學生看到舊的截止日期） | `generate_feedback_reports`/`generate_missing_reports` 的 `rmarkdown::render()` 未傳 `is_revision = REVISION_MODE`；模板預設 `is_revision = false` → 複評時仍呈現初評樣式 | 「複評回饋未傳 `is_revision`」|
| 未繳交學生的 0 分報告全部輸出失敗（`does not exist` 錯誤）| `generate_missing_reports` 的 `template_path` 用 `base_dir`（`_Validation_Results/W##/`）而非 `PROJECT_ROOT`；`_Templates/` 在專案根目錄 | 「generate_missing_reports template_path 路徑錯誤」|
| OMV 儲存變項偵測 `has_residuals=FALSE`，使用中文介面的學生建模分少 1 分 | jamovi 中文介面（zh-tw）將 "Residuals" 儲存為「殘差」；`check_saved_outputs` 的 `res_idx` 未含中文 pattern | 「殘差中文欄位名未偵測」|
| 全班 OMV 自動評分為 0（valid=FALSE），但 standalone 測試 valid=TRUE | `generate_personal_data.R` 在 source 時重新載入 `utils.R`，覆蓋 `grade_common.R` 的 `read_omv_metadata`（包裝版），導致 `validate_omv_data` 中 `$metadata$dataSet` 為 NULL | 「utils.R/grade_common.R read_omv_metadata 版本衝突」|

---

## 二、新 Bug 登記流程

### 登記時機
確認為**腳本問題**（非學生錯誤、非資料異常）且修復後，**必須**登記本檔。

### 欄位格式

```markdown
| Bug 名稱 | 週次 | 類型 | 根因 | 修復方式 | 影響檔案 |
|:---------|:----:|:-----|:-----|:---------|:---------|
| 【簡短描述】 | W## | A~H（見下方）| 為什麼會發生 | 怎麼修的 | 改了哪些檔案 |
```

### 類型分類（加在週次後的欄位）

| 類型代碼 | 類型 | 範例 |
|:--------:|:-----|:-----|
| **A** | StudentID/學號處理 | 前導零、10 位學號截斷、欄位名中英轉換 |
| **B** | Pattern/Regex | 偏態詞、否定詞感知、APA 語彙 |
| **C** | Path/目錄/檔名 | REVISION_MODE 切換、複評 CSV 檔名、Prep Report 路徑 |
| **D** | OMV/資料驗證 | Descriptives 偵測、metadata 路徑、中文欄位別名 |
| **E** | Section 提取/Report Schema | Heading regex、章節溢出、manual_questions 設計 |
| **F** | Manual Review CSV | StudentResponse 回填、overwrite 旗標、ManualTotal 換算 |
| **G** | Submission/Prepare | DOCX/PNG 收集、檔名推斷、模板檔過濾 |
| **H** | Feedback/累積報告 | 回饋模板、補交狀態、AutoFeedback 整合 |

### 登記後同步

- 若是**新症狀** → 更新一、症狀速查表新增一列
- 若是**共用函式**（`utils_docx.R` / `grade_common.R` / `prepare_submissions.R`）→ 更新 SKILL.md Section 七「已知高風險改版點」

---

## 三、Bug 歷史完整表（依登記日期降序）

| Bug | 週次 | 類型 | 根因 | 修復方式 | 影響檔案 |
|:----|:----:|:----:|:-----|:---------|:---------|
| **`generate_missing_reports` template_path 用 `base_dir` 而非 `PROJECT_ROOT`（0 分報告全部失敗）** | **W15** | C | `template_path <- file.path(base_dir, "_Templates", ...)` 中 `base_dir` 為 `_Validation_Results/W15/`，而 `_Templates/` 在專案根目錄；同週 `generate_feedback_reports` chunk 已正確使用 `PROJECT_ROOT`，僅 `generate_missing_reports` 漏改 → 17 名未繳交學生 0 分報告全部失敗 | 將 `base_dir` 改為 `PROJECT_ROOT` | **`grade_w15_assignment.Rmd`**（第 773 行） |
| **jamovi 中文介面「殘差」未被偵測（has_residuals=FALSE）** | **W15** | D | jamovi 中文介面（zh-tw）將 "Residuals" 欄位儲存為「殘差」；`check_saved_outputs` 的 `res_idx` pattern `"resid\|^RES"` 未含中文，`pred_idx` 已含「預測」但 `res_idx` 漏掉「殘差」→ 7 名使用中文介面的學生 `has_residuals=FALSE`，`sv_pts` 少 1 分 | `res_idx` 加入 `殘差`：`grepl("resid\|^RES\|殘差", fn, ignore.case=TRUE) & !sqr_idx`；重新執行評分後 5 人建模 9→10，2 人因其他因素較低（合理）| **`grade_w15_assignment.Rmd`**（`check_saved_outputs` 函式） |
| **`utils.R`/`grade_common.R` `read_omv_metadata` 版本衝突（source 覆蓋致全班 OMV 評分 0 分）** | **W15** | D | `utils.R::read_omv_metadata` 回傳 raw JSON（頂層為 `document, dataSet`），而 `grade_common.R::validate_omv_data` 存取 `omv_data$metadata$dataSet`（需包裝版）。`grade_w15_assignment.Rmd` setup chunk source `generate_personal_data.R`，後者在載入時重新 source `utils.R`，覆蓋 `grade_common.R` 的同名函式 → `validate_omv_data` 中 `omv_data$metadata$dataSet` 為 NULL → `valid=FALSE` → 全班 OMV 自動評分 0 分 | 更新 `utils.R::read_omv_metadata` 改為回傳 `list(metadata=fromJSON(...))` 包裝結構（與 grade_common.R 一致）；同步更新 `get_omv_variables` 路徑為 `meta$metadata$dataSet$fields` | **`_Scripts/utils.R`**（`read_omv_metadata` 與 `get_omv_variables` 函式） |
| **corrMatrix `plots=TRUE` 散佈圖矩陣被誤判為未找到散佈圖** | **W14** | E | `check_scatterplot()` 偵測 corrMatrix analysis binary 時只搜尋 `"scatter\|corrplot"`；但 jamovi 2.7+ 的 corrMatrix 將 Plots 選項序列化為 `plots = TRUE`（不含 "scatter"），且圖檔輸出至 `resources/` 目錄下；grep 無命中 → `has_scatterplot=FALSE` → 散佈圖 OMV 分 0 | (1) 將 corrMatrix analysis binary 搜尋 pattern 擴充為 `"scatter\|corrplot\|plots\\s*=\\s*TRUE"`；(2) 新增 PNG 保護層：若 `corrMatrix/resources/` 有 `.png` 檔則直接判定 has_scatterplot=TRUE；已套用至 `grade_w14_assignment.Rmd`（2026-06-07）；影響 3 人：楊曉鵬、楊程皓、蔡璨庭 | **`grade_w14_assignment.Rmd`**（`check_scatterplot` 函式，第 220-233 行） |
| **複評回饋未傳 `is_revision` → 學生看到「修正截止日期」而非「最終評分」通知** | **W6–W15** | H | `generate_feedback_reports` 與 `generate_missing_reports` 的 `rmarkdown::render()` params 未傳入 `is_revision = REVISION_MODE` 與 `revision_deadline`；模板預設 `is_revision = false` → 複評時仍顯示「補交與修正規範」，而非「本週 LAB 評量完成、正式評分見累積報告」 | 在 `grading_config` chunk 新增 `REVISION_DEADLINE <- "YYYY/MM/DD"`；在兩個 render 呼叫的 params 加入 `is_revision = REVISION_MODE` 與 `revision_deadline = if (!REVISION_MODE) REVISION_DEADLINE else ""`；W12 已修復（2026-05-26） | **`grade_w12_assignment.Rmd`**（已修）；W6–W11/W13–W15 待套用 |
| **Strategy 2 marker 逆序序列 → 提取值含 NA 和原始標記行** | **W13**（所有使用 answer_marker 的週次） | E | `(marker_idx + 1):length(answer_texts)` 當 marker 為最後一元素時，R 產生遞減序列 `c(n+1, n)` 而非空向量 → `answer_texts[c(n+1, n)]` = c(NA, 標記行) → paste 後提取值含 `NA` 與重複的標記行文字 | 改用明確判斷：`tail_texts <- if (marker_idx < length(answer_texts)) answer_texts[(marker_idx+1):length(answer_texts)] else character(0)`；同時加 `!is.na(answer_texts)` 防護 | **`utils_docx.R`**（第 777-789 行）|
| **Strategy 2 start_pos 未過濾 📋 操作說明段落** | **W13**（含 📋 的模板） | E | `start_pos` fallback 過濾器（約第 700-703 行）未含 `^\U0001F4CB`；W13 模板的「📋 操作說明：...適合度...APA...」段落同時符合 `APA_GOF` regex（含「適合度 APA」），被選為 start；end 計算時「3-1. 適合度檢定 APA」（位置 start+1）成為 GOF_Result end candidate → end = start → answer_texts = 📋 段落 → filter 後為空 | 在 start_pos 過濾器加入 `\U0001F4CB|^格式範例[:：]|^範例[:：]`，與 end-boundary 過濾器對齊 | **`utils_docx.R`**（第 700-703 行）|
| **問題提示段落誤判為節邊界（Q2 提取到 section header）** | **W13**（含「問題：」提示行的模板） | E | end-boundary 過濾器未排除 `^問題[:：]`；「問題：為什麼預期次數太小...」含 `預期次數`，符合 `Expected_Diagnosis` regex → 被用為 Q2 節的 end boundary → end = Q2 start → answer_texts = para_texts[start] = "Q2: 預期次數與適用條件"（section header） | 在 other_matches 過濾器加入 `^問題[:：]|^問[:：]` | **`utils_docx.R`**（第 739-742 行）|
| **Levene_Report table cell 遺漏（⚠️ 未修復）** | **W12**（可能所有週） | E | `extract_answers_by_headers()` 只讀 `content_type=="paragraph"`，學生將 Levene 診斷填入 Word 表格（table cells）→ `text_lev` 為空 → LeveneAPA = 0；此外學生 OMV 中的 Levene F/p 值可能與個人化期望值不同（jamovi 的 Levene 演算法與期望 RDS 計算方式有差） | 尚未修復；當前作法：教師手動核對 Word，更正 CSV + 重新 render 回饋；建議修復：在評分前讀取 `docx_summary` 中 `table cell` 列，合併至 `text_lev`（參考 W8 Fix 1 做法）；另外新增 jamovi Levene 容差（tol ≥ 0.05 → 0.1）或改為純文字比對 | **`grade_w12_assignment.Rmd`**（`text_lev` 計算區塊）；分數更正工具：`_Scripts/diag/fix_levene_114118120.R` |
| **「我的報告：」被誤判為節邊界（APA_Paired 章節提前截斷）** | **W12**（所有週適用） | E | Strategy 2 結束邊界過濾器（`extract_answers_by_headers` 第 738-741 行）只排除 `^我的回答[:：]`，未排除 `^我的報告[:：]` 等同義標記；學生回答 "我的報告：（相依樣本 t 檢定顯示...這結果...）" 同時符合 `Paired_Result` regex `相依.*t.*結果`，被誤判為下一節起點 → `end = position-1`，APA_Paired 只提取格式範例行，缺學生實際回答 | 在過濾器新增 `^我的報告[:：]|^我的說明[:：]|^我的診斷[:：]|^我的[:：]` 排除模式，確保任何「我的 XX：」開頭的段落均不視為節邊界；同步重跑 W12 評量並補發 114118120 回饋（APAPaired 2.5→5，TotalScore 56.83→59.33） | **`utils_docx.R`**（第 738-741 行）|
| **DOCX-only 學生完全被跳過（不進 grading_df、不進 Manual Review CSV）** | **W12**（其他週亦同） | G/F | `grade_word` chunk 只迭代 `omv_files`；有 DOCX 無 OMV 的學生既不進 `grading_results` 也不進 `all_answers`；`docx_only_students` chunk 雖有偵測但在 `export_results` 之後執行，加入 `grading_df` 無效；最終學生被 `generate_missing_reports` 誤判為「未繳交」產生 0 分報告 | 在 `grade_word` chunk OMV 迴圈結束後加入 DOCX-only 補充段：偵測有 DOCX 無 OMV 的學生 → 初始化 `grading_results[[sid]]`（OMV 分數全 0）→ 驗證 DOCX 檔名 → 提取 Word 內容存入 `all_answers` → 後續 export/manual_review/feedback 正常處理 | **`grade_w12_assignment.Rmd`**；其他週 W10/W13-W15 亦應套用 |
| **CSV 輸出路徑永遠寫至 `base_dir`（複評時不跟 `submission_dir`）** | **W10–W15** | C | 兩處 `output_file <- file.path(base_dir, csv_name)` 未依 `REVISION_MODE` 切換；複評時 CSV 寫至初評目錄，`update_week_revision()` 讀 `Revisions/` 找不到 → 需手動 cp | 新增 `csv_out_dir <- if (REVISION_MODE) submission_dir else base_dir`；兩處 `output_file` 均改用 `csv_out_dir` | **`grade_w10/12/13/14/15_assignment.Rmd`** |
| **Stage C 複評時不偵測新學生（補繳/請假學生 manual 計 0 分）** | **W10–W15** | F | Stage C 只對 `grading_df` 既有學生合併手動分數，不比對「複評才首次出現的學生」；W8/W9 已修復但 W10–W15 未套用 | Stage C 加入 `setdiff(grading_df$StudentID, existing_sids_in_csv)` 偵測 → append 新學生回答列到 Manual Review CSV；同步加入 `IsRevised` 警告與 `update_manual_review_responses()` 呼叫 | **`grade_w10/12/13/14/15_assignment.Rmd`** |
| **SE 驗算評分只查 t 值，但模板讓學生填 SE（系統性假陰性）** | **W9** | B/E | 作業模板格式 `(Mean−μ) ÷ t_obs_N` 要學生填 SE 結果；但 `check_se_verify_auto()` 只比對期望 t 值（±0.05）；學生寫 SE ≈ 0.95 而非 t ≈ 2.11 → 86% 學生 0 分。同時 df 容差 0.5 無法匹配 N=5/30/100 與 df=4/29/99 的差值 1.0 → df 全失敗 | (1) 新增 `exp_se` 參數，t 比對或 SE 比對任一通過即可；(2) df 容差從 0.5 改為 1.5，接受學生寫 N 值；(3) 有效數字 < 3 時啟用全文 fallback（掃描含 N=5/30/100 與小數的段落），解決部分學生 heading 提取到錯誤段落的問題 | **`grade_w9_assignment.Rmd`** |
| **SE_Verify heading 提取到「操作說明」而非計算結果** | **W9** | E | 個別學生（114118122）的 Word 結構使 SE_Verify heading regex 命中非預期標題 → 提取到「操作說明」＋chrome URL，有效數字只有 1 個 | 上述 fallback 機制（有效數字 < 3 → 全文掃描）已覆蓋此情境 | **`grade_w9_assignment.Rmd`** |
| **CI_Width 誤抓 Q3 標題（regex 跨節匹配）** | **W9** | E | CI_Width 的 start_regex 含 `CI.*寬度`，同時命中 Task 2 heading 與 Q3 heading `"Q3: 縮小 CI 寬度的代價"`；當學生的 Task 2 heading 未套 heading style 時，strategy 1 跳過 Task 2、從 Q3 開始提取，並延伸至文件末尾 | 移除 `CI.*寬度`，新 regex = `"任務.*2\|視覺化.*比較\|比較.*CI.*寬度"`；同步在 `extract_section_content` 策略 1 加入「我的回答：」後截取邏輯；刪除舊 CSV 觸發 Stage A 重新生成 | **`report_schema.R`**, **`utils_docx.R`** |
| **Word 表格 SD 值遺漏（SE 比值評分假陰性）** | **W8** | E | 學生將 jamovi Descriptives 輸出貼為 Word 表格；`extract_answers_by_headers()` 只讀 `content_type=="paragraph"`，`"table cell"` 被完全略過 → SD 值無法提取 → SE 比值評分 0 分 | (Fix 1) 在 `all_answers` 新增 `table_cell_text` 欄位（讀取全文件 table cells）；(Fix 3) SE_Ratio 評分改用 `se_calc_combined`（paragraph + table cell 合併文字）提取數值 | **`grade_w8_assignment.Rmd`** |
| **直方圖圖說置於子標題下（fallback 掃描失效）** | **W8** | E | 學生將 6 則圖說分別放在 heading 3 子標題（Pop_RT/Means_RT_N5...）下，且未用「Figure X.」格式（用「Pop_RT的直方圖。M = ..., SD = ...」）；(a) heading-based 提取截斷於第一個子標題 → `Histogram_Captions` 只含模板文字；(b) Fix 4 fallback 掃描用「Figure」作為必要條件，而學生未寫「Figure」→ fallback 仍未命中 | (Fix 4) 改用「同時含 M= 且含 SD=」的段落掃描，排除模板範例行（含 498.23/98.45 或以「範例：」開頭）；命中時評分 M/SD 值，並在回饋中加入格式提醒 | **`grade_w8_assignment.Rmd`** |
| **直方圖標題容差過嚴 + 模板範例數值污染** | **W8** | D/E | (a) tol=0.1 對學生將 M/SD 四捨五入為整數的情況過嚴（最大誤差 0.499）；(b) 模板「範例：Figure 1. M=498.23, SD=98.45」未被過濾，範例數字混入學生數值池造成假陽性/假陰性 | (Fix 2) 新增 `hist_lines` 過濾（移除「^APA 格式說明\|^範例[：:]\|^\\[在此置入」開頭行）；tol 由 0.1 改為 0.5 | **`grade_w8_assignment.Rmd`** |
| **Q1 Q-Q Plot 評分對新手過嚴（全班 86% 被判 0 分）** | **W7** | B/E | 報告模板為單一「Q-Q Plot 判讀」欄位，多數學生寫總體描述而非分變項；腳本要求「變項名 + 偏態詞」雙重命中才給分 → 25/29 學生 Q1 得 0 分 | 新增 **階層式新手保底評分**（`grade_q1_qqplot_auto`）：Tier 1=6 分（術語+方向+結論）、Tier 2=5 分（術語+方向）、Tier 3=3 分（僅術語）；傳統分變項路徑仍可達 10 分；未達滿分時 feedback 加入 `📌` 提示 | **`grade_w7_assignment.Rmd`** |
| **Z 分數偵測 metadata 路徑錯誤（系統性假陰性）** | **W7** | D | `check_z_score_bonus()` 讀 `omv_data$metadata$fields`（為 NULL）；正確路徑為 `omv_data$metadata$dataSet$fields`；jsonlite::fromJSON 將 JSON 陣列轉為 data.frame，原以 `sapply(fields, function(f) f$formula)` 迭代會靜默失敗；結果 86% 學生 Z 分數被判 0 分 | 改寫為 `check_z_score_complete()`：（1）路徑改為 `metadata$dataSet$fields`（2）用 `seq_len(nrow(fields))` 迭代 data.frame 列（3）跳過 Filter 列（`^Filter` 或 `^篩選條件` 或 `columnType=="filter"`）避免 Filter 3 的 `-3 < Z(Total_Score) < 3` 誤觸發 | **`grade_w7_assignment.Rmd`** |
| **Q1 Q-Q Plot 語彙缺乏 Q-Q 特有判讀用語（假陰性）** | **W7** | B | pattern 只認「正偏/右偏」傳統偏態詞；學生用「點上翹/尾部偏離對角線/點沿對角線」等 Q-Q Plot 正確判讀用語被判 0 分 | 新增 `pat_positive_skew`/`pat_negative_skew`/`pat_symmetric`：併入「上翹/下彎/尾部上下/點落對角/點沿直線」等語彙 | **`grade_w7_assignment.Rmd`** |
| **W7 `score_max=10` 與其他週不一致（老師誤填陷阱）** | **W7** | F | W5/W6 `score_max=5`（填 0-5）；W7 設為 10（應填 0-10）；老師慣性填 5 → 學生拿一半分 | 改為 `score_max = 5`（與 W5/W6 一致）；實際配分由 `manual_weight=10` 決定，換算公式 `(raw_sum / (n × 5)) × 10` 自動擴展 | **`report_schema.R`** |
| **Z 分數標準化未驗證兩種作法（不符教學目標）** | **W7** | D | W07 教學要求一項變項用 `Z()` 函數、另一項用 `VMEAN/VSTDEV` 組合公式；`check_z_score_bonus()` 只要任一方法命中即給滿 10 分，學生兩個變項都用 Z() 也拿滿分 | 改寫為 `check_z_score_complete()`：分別偵測「Z() 函數法」(5分) 與「VMEAN+VSTDEV 組合法」(5分)，兩者獨立計分 | **`grade_w7_assignment.Rmd`** |
| **W7 報告結構只檢查 MANUAL_QUESTIONS（邏輯錯誤）** | **W7** | E | `required_sections <- MANUAL_QUESTIONS` 在 W7 只有 `Q3_RealityGap` 一題；只要 Q3 heading 抓到即 5/5 滿分 | 改為 `required_sections <- names(REPORT_HEADERS)`（檢查所有 header 章節） | **`grade_w7_assignment.Rmd`** |
| **Q2 Shapiro-Wilk「顯著」誤命中「不顯著」（Fatal）** | **W7** | B | `grepl("顯著", "不顯著")` 為 TRUE，無否定感知；reject pattern 含「顯著」、support pattern 含「不顯著」 → 學生寫「RT 不顯著，支持常態」被 reject pattern 誤判為正確給 5 分 | 新增 `preprocess_sig_negation()` 將「不/未/無/沒/尚未/並未 + 顯著」與「not significant」替換為 `[NOT_SIG]` token，再進行 pattern 比對；support pattern 改為匹配 `\\[NOT_SIG\\]` | **`grade_w7_assignment.Rmd`** |
| **prepare_revisions() 未收集 PNG 圖檔** | **W06** | G | 逐學生迴圈只收 OMV/DOCX，未偵測 `accepts_png`；學生在 Revision/ 上傳修正版 PNG → 評量腳本找不到 → PngScore=0 | 新增 `all_png_copies` 收集器 + 迴圈內 `png_files_rev` 偵測 + step 7b 複製段落；empty_ids 判斷同時考慮 PNG | **`prepare_submissions.R`** |
| **notify_revision 讀取 Grading Report 假設英文欄位名** | **W7+** | A | W7 Grading Report 使用中文欄位（`學號`/`姓名`/`總分`）；`notify_revision.R` 直接讀 `grades$StudentID` → `NULL` → `integer(0)` → 0-row 賦值錯誤 | 讀 CSV 後新增 `col_map` 正規化迴圈：`學號→StudentID`、`姓名→Name`、`總分→TotalScore` | **`notify_revision.R`** |
| **Figure1_Caption 提取帶入下一節模板文字** | **W6** | E | `extract_answers_by_headers()` 擷取「Figure 1」與「Figure 2」heading 之間所有段落；模板文字「二、箱形圖 (Boxplot)」被納入 Figure1 內容 → 期望值比對雜訊 | 新增 `clean_figure1_text()` helper：依 `^[一二三四五六七八九十]+[、．]` 截斷中文節標記前內容 | **`grade_w6_word.R`** |
| **Boxplot Mdn/IQR 容差 0.1 對整數分數過嚴** | **W6** | D | `Total_Score` 為 5-25 整數；jamovi 分位數演算法與 R `type=7` 可差 1 整數單位（例：R Mdn=17，jamovi Mdn=16）；tol=0.1 使正確答案也被判失敗 | boxplot caption 的 `check_apa_numeric_values()` tol 從 `0.1` 改為 `1.5` | **`grade_w6_word.R`** |
| **`validate_omv_data()` 不支援中文欄位名稱別名** | **W6+** | D | 學生 OMV 欄位名為中文（`總分`），`required_vars` 期望英文（`Total_Score`）；case-insensitive 比對無法跨中英文差異 → OMV 相關分數全歸 0 | 新增 `var_aliases = list()` 參數；比對時對每個 `required_var` 先展開 `var_aliases[[v]]` 別名向量再做 OR 比對；W6 加入 `list(Total_Score = c("總分", "total score", "TS"))` | **`grade_common.R`**, **`grade_w6_assignment.Rmd`** |
| **`validate_omv_data()` 欄位比對 case-sensitive（假陽性）** | **W5-W15** | D | `setdiff(required_vars, col_names)` 區分大小寫；`total_score`/`Total_score` 無法命中 `Total_Score` → 誤報驗證失敗 | 改為 `required_vars[!tolower(required_vars) %in% tolower(col_names)]`（case-insensitive） | **`grade_common.R`** |
| **W6 未 source grade_common.R** | **W6** | C | W6 setup chunk 只 source `grade_w6_word.R`，未引入 `grade_common.R`；`validate_omv_data()` 無法呼叫 | 在 W6 setup chunk 新增 `source("...grade_common.R")` | **`grade_w6_assignment.Rmd`** |
| **複評 CSV 路徑寫入 base_dir（未跟 submission_dir）** | **W6/W7** | C | `output_file <- file.path(base_dir, csv_name)` 永遠寫初評目錄；複評時 `update_week_revision()` 讀 `base_dir/Revisions/W##_Revision_Grading_Report.csv` → 找不到 | 新增 `csv_out_dir <- if (REVISION_MODE) submission_dir else base_dir`，兩處 CSV 寫入均改用 `csv_out_dir` | **`grade_w6/7_assignment.Rmd`** |
| **模板檔案（W#_Report_Template.docx）被複製進作業資料夾** | **全週** | G | `all_docx` 收集所有 `.docx` 不篩選；模板檔名不含學號 → `parse_submission_files` 無法解析 → `student_id = UNKNOWN` → 產生 NA 列 | 在 `all_omv`/`all_docx`/`detect_near_omv_files` 呼叫前加過濾：`grepl("^[0-9]", fname)` | **`prepare_submissions.R`** |
| **DOCX-only 學生被誤判為未繳** | **全週** | G | `get_submitted_ids()` 只讀 `fi_unique`（OMV），`docx_fi_unique` 未納入 | 步驟 8 改為 union：`submitted_ids = union(omv_submitted, docx_submitted)` | **`prepare_submissions.R`** |
| **副檔名拼錯（.omt 等）被靜默丟棄** | **全週** | G | `all_omv` 過濾只允許 `\\.omv$`；`.omt` 歸入 `all_other` 完全略過 | 新增 `detect_near_omv_files()`；`.omt/.omf` 納入 OMV 管線；`parse_submission_files` 標記 `EXT_WARN`；`config.R` 的 omv_patterns 改用 `\\.omvt?$` | **`prepare_submissions.R`**, **`config.R`** |
| **10位學號被截斷為假9位學號** | **全週** | A | `parse_student_id()` 的 `^([0-9]{9})` 提取前9位後不驗證後方緊接底線；10位學號提取出假學號 | 改用 `^([0-9]+)` 取全部前導數字後判斷位數；≠9位 → `ID_TOO_LONG`/`ID_TOO_SHORT`；另新增 `resolve_id_by_name()` 取檔名中姓名比對 roster | **`prepare_submissions.R`** |
| **回饋報告未顯示各題自動評分細節** | **W6+** | H | `AutoFeedback` 只存於 Manual Review CSV，未傳入回饋模板 | 讀 `AutoFeedback` 欄 → build `student_auto_fb_map` → 傳 `auto_feedback_map`；模板新增 🤖 **自動評分** 區塊 | **`grade_w6_assignment.Rmd`**, **`Individual_Feedback_Template.Rmd`** |
| **`理論常態分佈` 觸發 symmetric 方向假陽性** | **W6** | B | 報告模板含「疊加曲線為理論常態分佈」，strip 後仍留「常態分佈」字串；symmetric 方向 pattern 含 `常態` → 誤判 | symmetric 方向 pattern 移除泛化 `常態\|normal`，改為明確前綴：`近似常態\|接近常態\|呈.*常態分佈` | **`grade_w6_assignment.Rmd`** |
| **模板殘留標記造成自動評分假陽性** | **W6** | B | 學生未移除 `[正偏/負偏/對稱]`、`[XX.XX]` 等佔位符；`[正偏/負偏/對稱]` 讓方向詞比對永遠命中 | 新增 `strip_template_markers()`：① 全形【】整個移除；② 含 `/` 的多選一 `[A/B/C]` 整個移除；③ 其他 `[值]` 保留內容去除括號 | **`utils_docx.R`**, **`grade_w6_assignment.Rmd`** |
| **Mdn/IQR 容差過嚴（jamovi 1 位小數）** | **W6** | D | jamovi 顯示至小數後 1 位，四捨五入最大誤差 0.05；tol=0.05 遇到捨入邊界誤判 | boxplot Mdn/IQR 的 tol 從 0.05 改為 0.1 | **`grade_w6_assignment.Rmd`** |
| **Figure 2 boxplot N 容差誤扣分** | **W6** | D | 原評分要求 caption 含 N，但 boxplot 不顯示 N；部分學生未寫 N → 扣分 | 移除 boxplot caption 的 N 要求；改為只檢查 Mdn（3分）+ IQR（3分） | **`grade_w6_assignment.Rmd`** |
| **`compute_w6_expected()` n_clean 不符學生資料** | **W6** | D | 只套 Age 過濾，未套 RT_ms 過濾；Age 用 `>=16 & <=30` 而非 W04 一致的 `<=100` | 新增 RT_ms 過濾（去除非數值與值=9999）；Age 改為 `<=100` | **`grade_w6_assignment.Rmd`** |
| **`find_pattern` 在 descriptives 偵測區塊不可用** | **W6** | D | `find_pattern()` 定義在 `jmvbox` if 區塊內，descriptives 新區塊呼叫時已超出 scope | 將 `find_pattern()` 移至 for 迴圈前定義 | **`grade_w6_assignment.Rmd`** |
| **Descriptives 模組製圖被評 0 分** | **W6** | D | `check_plots_v27()` 只掃 `jmvhist`/`jmvbox` 專屬資料夾；部分學生由 Descriptives 模組啟用 `hist=TRUE`/`box=TRUE` → 找不到 | 新增 descriptives 資料夾偵測：讀 analysis 二進位搜尋 "hist"/"box" ASCII；偵測到 → 給滿分 + 提示「建議改用 Plots Tab」 | **`grade_w6_assignment.Rmd`** |
| **DiagQ2 使用示範資料被誤判為 pattern bug** | **W5** | B | 劉席緯/顏攸庭/蘇昱珊等人 DiagQ2=2（dir=0）最初被判定為 pattern bug，實際上是學生用示範資料（Mean=50.81, Median=50）而非個人資料 | 不應更正這些學生分數；辨識方式：DiagQ2 文字出現 50.81 或其他與期望 M/Mdn 差距 > 1 的數值 | 偵測記錄 `check_q2_docx.R` |
| **DiagQ2 英文混搭口語表達不識別** | **W5+** | B | 學生寫「Median比較大」（英文 Median + 中文比較大），不含 `>` 符號，無法命中 `Median.*>` pattern → 0/3 方向分 | 新增 `Median.*大\|Median.*比.*大\|Median.*高\|Mdn.*大\|Mdn.*高`（及對稱 Mean 版本）| **`grade_w5_assignment.Rmd`** |
| **DiagQ2 反向表達不識別（mean < median 同義式）** | **W5+** | B | `median_greater` 只比對「中位數大/高」的正向表達，學生寫「平均小於中位數」→ 0/3 方向分 | `median_greater` 新增反向 pattern：`平均.*小於.*中位\|平均.*低於.*中位\|M\\s*<\\s*Mdn\|mean.*<.*median` | **`grade_w5_assignment.Rmd`** |
| **DiagQ1 類別詞部分分數缺失** | **W5+** | B | 學生用「接近常態分佈」「偏斜不嚴重」等一般性描述，不符合 mild/moderate 精確關鍵詞 → 0/2，但描述方向並未錯誤 | 新增 `cat_partial` 邏輯：非 symmetric 類別且匹配一般性描述 → 1/2 部分給分，feedback 顯示 `△` | **`grade_w5_assignment.Rmd`** |
| **複評 Manual Review 無法辨識修正版提交** | **W5+** | F | 複評模式下 `update_manual_review_responses()` 覆寫 StudentResponse，但無旗標標示哪些列已更新 | 複評時答案有異動 → 清空 `Score`（NA）+ 寫入 `IsRevised=TRUE`；未改動 → 保留原分數 + `IsRevised=FALSE` | **`utils_docx.R`** |
| **Manual Review Stage C 不更新 CSV（新學生列未補充）** | **W5+** | F | Stage C（`n_graded>0`）只讀分數整合進 results，不寫回 CSV；複評有新學生（補繳/首次提交）其列不會被加入，manual 計入 0 分 | Stage C 加入：① 偵測 `grading_df$學號` 不在 CSV 的新學生 → append 其回答列（Score=NA）；② `update_manual_review_responses(overwrite=TRUE)` 更新 IsRevised 旗標 | ✅ **`grade_w8/w9_assignment.Rmd`** 已修；⚠️ **W10–W15 待修**（複評前若有新學生會復現） |
| **累積報告補交狀態誤判為「未繳交」** | **全週** | H | `Cumulative_Report_Template.Rmd` 狀態判斷最外層先攔截 `is.na(initial)` → `⬜ 未繳交`，未檢查 `revision` 是否有值（補交情境） | 新增最高優先條件：`is.na(initial) & !is.na(revision)` → `📬 補交已評量`；Excel 上色同步新增淺橙色 | **`_Templates/Cumulative_Report_Template.Rmd`** |
| **複評 `prep_omv_info` 誤用初評 Prep Report** | **W4/W5** | C | 學生複評修正了檔名（FORMAT_WARN → OK），但 `prep_omv_info` 固定讀初評 Prep Report，複評仍扣 5 分 | `REVISION_MODE=TRUE` 時優先讀 `W##_Revision_Preparation_Report.csv`，不存在則 fallback 初評 | **`grade_w4/5_assignment.Rmd`** |
| **`generate_missing_reports` feedback_dir 未跟隨模式** | **W5** | C | 硬接 `file.path(target_dir, "Feedback")`，複評時未放入 `Revisions/Feedback/` | 改用 `file.path(submission_dir, "Feedback")` | **`grade_w5_assignment.Rmd`** |
| **`manual_review_file` 複評時路徑錯誤** | **W5** | C | `if (REVISION_MODE) file.path(target_dir, "Revisions")` → 找不到初評已填的 CSV | 固定從 `target_dir`（基礎目錄）讀，不受 REVISION_MODE 影響 | **`grade_w5_assignment.Rmd`** |
| **複評 CSV 檔名與 `update_week_revision()` 不符** | **W4/W5** | C | 複評輸出 `W##_Grading_Report.csv`，但 `cumulative_grades.R` 預期 `W##_Revision_Grading_Report.csv` | 複評時 `csv_name <- sprintf("W%02d_Revision_Grading_Report.csv", CURRENT_WEEK)` | **`grade_w4/5_assignment.Rmd`** |
| **REVISION_MODE 未切換掃描目錄** | **W4** | C | `target_dir` 固定為 `W04/`，複評時仍掃初評目錄 | 分離 `base_dir`（固定）與 `target_dir`（依模式切換）；W5 對應為 `submission_dir` | **`grade_w4_assignment.Rmd`** |
| **DiagQ1 絕對值比對失效（Unicode fix 後）** | **W5** | B | `near_match(nums, abs(skew_val))` 期望正數；fix 後 nums 含 `-0.30`，`\|-0.30 - 0.30\| = 0.60` 超容差 | 改為 `any(abs(abs(nums) - abs(skew_val)) <= 0.05)` | **`grade_w5_assignment.Rmd`** |
| **Unicode 減號無法解析（`−` U+2212）** | **W5** | B | `extract_numbers()` regex `[-+]?` 只匹配 ASCII，jamovi/Word 的 `−` 被剝去，負數提取為正數 | `gsub("\u2212\|\uff0d", "-", text)` 預處理 | **`grade_w5_assignment.Rmd`** |
| **ManualTotal 超出上限（舊 CSV 多題干擾）** | **W5** | F | `read_manual_review()` 加總 CSV 全部行，不管 QuestionID 是否在 `schema$manual_questions` | 加過濾：`student_rows <- student_rows[QuestionID %in% schema$manual_questions, ]` | **`utils_docx.R`** |
| 修正版 OMV 檔名無法辨識類型 | W3 複評 | G | 全形底線/雙副檔名等變體判定為 UNKNOWN | 新增 `fuzzy_infer_omv_type()`：Stage 1 清理 + Stage 2 關鍵字 | `prepare_submissions.R` |
| `prepare_revisions()` 遺漏 DOCX 收集 | W3+ | G | `list.files(pattern=".omv$")` 且無 DOCX 分支 | 新增 DOCX 收集分支（`accepts_docx`）+ 統一管線 | `prepare_submissions.R` |
| 複評模式不更新 Manual Review CSV | W3 | F | 複評時欄位已有初評內容，`overwrite=FALSE` 全跳過 | 新增 `overwrite_responses` 參數，複評傳 `TRUE` | `utils_docx.R`, `grade_w3` |
| Manual Review CSV StudentResponse 為空 | W4 | F | Stage A 產出時 `all_answers` 尚無內容 | 新增 `update_manual_review_responses()`，Stage B 自動回填 | `utils_docx.R`, `grade_w4` |
| Q4 StudentResponse 過度納入後續章節 | W4 | E | `extract_qa_pairs()` 最後一題延伸到文件結尾 | 新增 heading style 偵測 + `section_end_pattern` 備援 | `utils_docx.R` |
| `normalize_grading_report` 忽略 ManualTotal | 全週 | F | `AutoTotal` 優先找到即停，ManualTotal 未加入 | 新增優先序：AutoTotal+ManualTotal→標準週 | `grade_common.R` |
| Grading Report 檔名格式不一致 | W3/W4/W6 | C | `W%d_` vs `W%02d_` | 統一 `sprintf("W%02d_...", CURRENT_WEEK)` | `grade_w3/4/6` |
| `fname_notes` 未整合入回饋 | W3 | H | 收集了標註但 feedback 組合未引用 | 加入 `if (length(fname_notes) > 0)` 插入段 | `grade_w3` |
| `prep_r` NULL 存取錯誤 | W3 | H | `get_prep()` 回傳 NULL 直接存取 `$was_renamed` | 加 `!is.null(prep_r) &&` NULL 保護 | `grade_w3` |
| jamovi 截圖 5 KB 誤判 | W6 | E | 箱形圖壓縮率高（500×500px 僅 4.9KB） | 改用 `read_png_header()` 讀 IHDR，px ≥ 300 為有效 | `utils_docx.R` |
| APA_Desc 提取跨章節溢出 | W3 | E | `end_heading_regex` 截斷位置錯誤 | `extract_section_content` 新增同層標題截斷保護 | `utils_docx.R` |
| 嵌套 render chunk 名衝突 | W3 | H | 子模板 chunk 名與父腳本重複 | 子模板使用獨立命名 | 回饋模板 |
| Rmd `cat("---")` YAML 衝突 | W5 | H | pandoc 將 `---` 解釋為 YAML 起始 | 改用 `<hr>` | 回饋模板 |
| 軸標籤檢測位置錯誤 | W6 | D | 查 metadata.json 而非 analysis 檔 | 改用二進位搜尋 analysis 檔 | `grade_w6` |
| Box Plot 選項名稱錯誤 | W6 | D | 搜尋 "outlier labels" | 改為 "Show outliers" | `grade_w6` |
| Word 內容提取回退失效 | W6 | E | 策略1成功→跳過策略2（全有全無） | 改為逐題獨立判斷回退 | `utils_docx.R` |
| StudentID 前導零遺失 | W7 | A | `read.csv()` 自動轉數字 | 雙重防護：寫入補零 + 讀取修復 | `utils_docx.R`, `grade_w7` |
| **jpower OMV 偵測使用目錄名而非內容（jpower_omv 全 0 分）** | **W12** | D | `check_jpower()` 以 `grepl("jpower", basename(all_dirs))` 篩選目錄；但 jamovi 實際將 jpower 結果嵌入 `ttestIS`/`ttestPS` 的數字編號目錄（如 `10 ttestIS`），目錄名不含 "jpower" → 迴圈空跑，`has_jpower_indep/paired` 永遠 FALSE | 改為迭代 `all_dirs` 全部目錄，讀取二進位 analysis 檔，若含 "jpower" 字串才進入 t-test 類型判斷 | **`grade_w12_assignment.Rmd`** |
| **jpower Word 評分遺漏表格欄位（table cell 不讀）+ 條件文字假陽性** | **W12** | E/B | (1) `extract_answers_by_headers()` 的 `extract_section_content()` 只讀 `content_type=="paragraph"`，學生填入表格（table cell）的 N/d 值完全遺漏；(2) 段落中含條件說明「α = .05」，`extract_numbers()` 提取 0.05；與 d_input=0.06（tol=0.05）差距 0.01 ≤ 0.05 → 假陽性得 1.25 分 | 新增 `get_jpower_answer_text()` helper：使用 `officer::docx_summary()` 同時讀 paragraph + table cell，並過濾含 `^條件\|α\s*=\|power\s*=.*0\.8\|雙尾\|單尾` 的條件說明行；`all_answers` 加入 `docx_path` 欄供 helper 呼叫 | **`grade_w12_assignment.Rmd`** |
| **APA_Independent 章節提前截斷（學生 APA 值全 0 分）** | **W12** | E | `Independent_Result` header regex 含 `Score_T1.*比較`，命中學生在 APA 段落內的子標題「1. Score_T1 的檢定結果（前測分數比較）」→ `extract_section_content()` 以此為 `end_pos`，APA_Independent 內容被截斷在子標題前，無法提取學生填寫的 t/df/d 值 | `report_schema.R` W12 `Independent_Result` 移除 `\|Score_T1.*比較` | **`report_schema.R`** |
| **`preprocess_sig_negation` 不識別「未達顯著」** | **W7+** | B | pattern `(不\|未\|…)顯著` 中 `未` 只匹配緊接「顯著」；「未達顯著」在「未」與「顯著」之間有「達」字 → `[NOT_SIG]` 無法替換 → `grepl("顯著", …)` 命中「未達顯著」，誤判為 reject | 將 `未` 改為 `未.{0,2}` | **`grade_common.R`** |
| **APA 獨立 t d 值使用帶符號值匹配（負 d 比對失敗）** | **W12** | B | `chk_d <- check_apa_numeric_values(text_ind, list(d = exp$d_independent), tol = 0.05)`；當 `d_independent` 為負（如 −0.11）時，`near_match(nums, -0.11)` 要求文字中出現 −0.11；但 APA 格式慣例 d 報告正值（0.11）→ 比對失敗 | 改為 `d_abs_ind <- abs(exp$d_independent)` 後傳入 `check_apa_numeric_values` | **`grade_w12_assignment.Rmd`** |
| **Levene 評分要求 F 值（與教學目標不符）** | **W12** | E | Levene's Test 教學目標是「判斷變異數同質性並決定用 Student 或 Welch」；F 值只是中間結果，不應評分；原設計 F 值 2 分、p 值 1 分、決策 2 分 → 重心放錯 | 重設計：移除 F 值評分，p 值 → 2 分，Student/Welch 決策 → 3 分；總計仍 5 分 | **`grade_w12_assignment.Rmd`** |
| **APA t 值帶符號匹配失敗（負 t 無法對比正期望值）** | **W12** | B | 與 d 值同理：學生寫 `t = -0.391`，`near_match(-0.391, 0.391, 0.1)` = FALSE；`extract_numbers()` 保留符號 | 改用 `abs(abs(nums_ind) - t_abs) <= 0.1`，同時對 APA_Independent 的 t/d 和 APA_Paired 的 t/d 均採 abs 比對 | **`grade_w12_assignment.Rmd`** |
| **jpower Word fallback 造成假陽性（條件段落 α=.05 重新混入）** | **W12** | B/E | `get_jpower_answer_text()` 返回空字串後，fallback `if (!nzchar) text_41 <- ans[["JPower_4_1"]]` 重新引入段落原文（含「α = .05」）；0.05 在 tol=0.05 範圍內匹配 d_input → 得 1.25 分假陽性 | 移除 fallback；helper 為空時直接用空字串（no-fallback policy） | **`grade_w12_assignment.Rmd`** |
| **jpower 4-2 section 溢出至「五、觀念辨析」標題（NBSP 空表格仍觸發 had_text）** | **W12** | E | 報告模板 `&nbsp;` 佔位符轉 docx 後為 U+00A0（非斷行空格）；`trimws()` 不剝除 U+00A0 → `nzchar()` 返回 TRUE → `had_text=TRUE`；同時 Q1_Design end_regex 不匹配「五、觀念辨析」節標題，4-2 section 延伸至 Q1 前，「五、觀念辨析」文字滲入 text_42 → 5 人全 0 觸發早停 | (1) `get_jpower_answer_text()` 清理加 `gsub(" "," ",rows)` 後再 `trimws`；(2) 4-2 end_regex 加入 `\|^五[、，]\|觀念辨析`；(3) `had_text` 改為需 `length(extract_numbers(text)) > 0` 才設 TRUE | **`grade_w12_assignment.Rmd`** |

---

## 四、StudentID 格式處理（詳細規則）

台灣學號 9 位數字含前導零（`000000000`）。`read.csv()` 自動轉數字 → 匹配失敗。

### CSV 寫入補零（`utils_docx.R`）

```r
long_df$StudentID <- as.character(long_df$StudentID)
unique_ids <- unique(long_df$StudentID)
if (all(grepl("^[0-9]+$", unique_ids))) {
  if (max(nchar(unique_ids), na.rm=TRUE) < 4)
    long_df$StudentID <- sprintf("%09d", as.integer(long_df$StudentID))
}
```

### CSV 讀取修復（評量腳本）

```r
df <- read.csv(manual_file, stringsAsFactors=FALSE, colClasses="character")
if ("StudentID" %in% names(df)) {
  df$StudentID <- as.character(df$StudentID)
  if (all(grepl("^[0-9]+$", df$StudentID)) && max(nchar(df$StudentID)) < 4)
    df$StudentID <- sprintf("%09d", as.integer(df$StudentID))
}
```

### 驗證

debug 訊息應顯示：`匹配結果: 43/43 位學生成功匹配`（不是 0/43）

---

## 五、臨時診斷腳本規則

> **優先序**：Read/Grep/Bash 工具 → 呼叫現有 `run_*.R` → 最後才建立臨時腳本

| 層次 | 適用情境 | 動作 |
|:-----|:---------|:-----|
| 1 | 讀取 CSV / 查欄位值 / 確認檔案 | 直接用 Read / Grep / Bash 工具，不寫腳本 |
| 2 | 流程性任務（grade / distribute） | 呼叫現有 `run_*.R` |
| 3 | 需要 R 計算且上面無法解決 | 寫至 `_Scripts/diag/`，命名 `YYMMDD_描述.R`，**用後刪除** |
| 4 | 下次還會用到的流程 | 才放 `_Scripts/`，需說明為「永久腳本」 |

預定 W11 整頓：清空 `_Scripts/diag/`。
