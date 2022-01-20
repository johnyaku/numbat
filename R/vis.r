########################### Visualizations ############################

pal = RColorBrewer::brewer.pal(n = 8, 'Set1')

#' @export
cnv_colors = c("neu" = "gray", "neu_up" = "gray", "neu_down" = "gray20",
        "del_up" = "royalblue", "del_down" = "darkblue", 
        "loh_up" = "darkgreen", "loh_down" = "olivedrab4",
        "amp_up" = "red", "amp_down" = "tomato3",
        "del_1_up" = "royalblue", "del_1_down" = "darkblue", 
        "loh_1_up" = "darkgreen", "loh_1_down" = "olivedrab4",
        "amp_1_up" = "red", "amp_1_down" = "tomato3",
        "del_2_up" = "royalblue", "del_2_down" = "darkblue", 
        "loh_2_up" = "darkgreen", "loh_2_down" = "olivedrab4",
        "amp_2_up" = "red", "amp_2_down" = "tomato3",
        "del_up_1" = "royalblue", "del_down_1" = "darkblue", 
        "loh_up_1" = "darkgreen", "loh_down_1" = "olivedrab4",
        "amp_up_1" = "red", "amp_down_1" = "tomato3",
        "del_up_2" = "royalblue", "del_down_2" = "darkblue", 
        "loh_up_2" = "darkgreen", "loh_down_2" = "olivedrab4",
        "amp_up_2" = "red", "amp_down_2" = "tomato3",
        "bamp" = "salmon", "bdel" = "skyblue",
        "amp" = "tomato3", "loh" = "olivedrab4", "del" = "royalblue", "neu2" = "gray30",
        "theta_up" = "darkgreen", "theta_down" = "olivedrab4",
        "theta_1_up" = "darkgreen", "theta_1_down" = "olivedrab4",
        "theta_2_up" = "darkgreen", "theta_2_down" = "olivedrab4",
        "theta_up_1" = "darkgreen", "theta_down_1" = "olivedrab4",
        "theta_up_2" = "darkgreen", "theta_down_2" = "olivedrab4",
        '0|1' = 'red', '1|0' = 'blue',
        'major' = '#66C2A5', 'minor' = '#FC8D62'
    )


#' @export
plot_sc_exp = function(exp_post, segs_consensus, size = 0.05, censor = 0) {
    
    # cell_order = exp_post %>% 
    #     filter(!cnv_state %in% c('neu', 'loh')) %>%
    #     left_join(cell_annot, by = 'cell') %>%
    #     group_by(cell_group) %>%
    #     do(
    #         reshape2::dcast(., cell ~ seg, value.var = 'phi_mle') %>%
    #         tibble::column_to_rownames('cell') %>%
    #         dist() %>%
    #         hclust %>%
    #         {.$labels[.$order]} %>%
    #         as.data.frame()
    #     ) %>%
    #     set_names(c('cell_group', 'cell'))

    exp_post = exp_post %>% filter(n > 15)

    exp_post = exp_post %>% 
            inner_join(
                segs_consensus %>% select(seg = seg_cons, CHROM, seg_start, seg_end),
                by = 'seg'
            ) %>%
            mutate(phi_mle = ifelse(phi_mle > 1-censor & phi_mle < 1+censor, 1, phi_mle))
            # mutate(cell = factor(cell, cell_order$cell))

    ggplot(
        exp_post,
        aes(x = seg_start, xend = seg_end, y = cell, yend = cell, color = phi_mle)
    ) +
    theme_classic() +
    geom_segment(size = size) +
    theme(
        panel.spacing = unit(0, 'mm'),
        panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
        strip.background = element_blank(),
        axis.text.y = element_blank()
    ) +
    scale_x_continuous(expand = expansion(0)) +
    facet_grid(group~CHROM, space = 'free', scale = 'free') +
    scale_color_gradient2(low = 'blue', mid = 'white', high = 'red', midpoint = 1, limits = c(0.5, 2), oob = scales::oob_squish)
}

#' @export
plot_sc_allele = function(df_allele, bulk_subtrees, clone_post) {
    
    snp_seg = bulk_subtrees %>%
        filter(!is.na(pAD)) %>%
        mutate(haplo = case_when(
            str_detect(state, 'up') ~ 'major',
            str_detect(state, 'down') ~ 'minor',
            T ~ ifelse(pBAF > 0.5, 'major', 'minor')
        )) %>%
        select(snp_id, snp_index, sample, seg, haplo) %>%
        inner_join(
            segs_consensus,
            by = c('sample', 'seg')
        )

    snp_neu_haplo = bulk_subtrees %>% filter(sample == 1) %>%
        mutate(haplo = ifelse(pBAF > 0.5, 'major', 'minor')) %>% 
        filter(!is.na(haplo)) %>%
        {setNames(.$haplo, .$snp_id)}
    
    
    pal = RColorBrewer::brewer.pal(n = 8, 'Set1')

    p = df_allele %>% 
        left_join(
            snp_seg %>% select(snp_id, haplo, cnv_state),
            by = 'snp_id'
        ) %>% 
        mutate(haplo = ifelse(is.na(haplo), snp_neu_haplo[snp_id], haplo)) %>%
        mutate(cnv_state = ifelse(is.na(cnv_state), 'neu', cnv_state)) %>%
        mutate(pBAF = ifelse(GT == '1|0', AR, 1-AR)) %>%
        filter(!is.na(haplo)) %>%
        mutate(MAF = ifelse(haplo == 'major', pBAF, 1-pBAF)) %>%
        left_join(clone_post, by = 'cell') %>%
        arrange(clone) %>%
        arrange(CHROM, POS) %>%
        mutate(snp_index = as.integer(factor(snp_id, unique(snp_id)))) %>%
        ggplot(
            aes(x = snp_index, y = cell, color = MAF)
        ) +
        theme_classic() +
        geom_point(alpha = 0.5, pch = 16, size = 1) +
        theme(
            axis.text.y = element_blank(),
            axis.ticks.y = element_blank(),
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'white', fill = NA),
        ) +
        facet_grid(clone~CHROM, space = 'free', scale = 'free') +
        scale_x_discrete(expand = expansion(0)) +
        scale_color_gradient(low = pal[1], high = pal[2])
    
    return(p)
}

#' @export
clone_vs_annot = function(clone_post, cell_annot) {
    clone_post %>% 
    rename(clone = clone_opt) %>%
    filter(!is.na(clone)) %>%
    left_join(cell_annot, by = 'cell') %>%
    count(clone, cell_type) %>%
    arrange(cell_type) %>%
    mutate(clone = factor(clone, rev(unique(clone)))) %>%
    group_by(cell_type) %>%
    mutate(frac = n/sum(n)) %>%
    ggplot(
        aes(x = cell_type, y = clone, fill = frac, label = n)
    ) +
    theme_classic() +
    geom_tile() +
    geom_text() +
    theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
    scale_fill_gradient(low = 'white', high = 'red') +
    xlab('')
}

#' @export
plot_markers = function(sample, count_mat, cell_annot, markers, clone_post, pal_annot = NULL) {

    if (is.null(pal_annot)) {
        pal_annot = getPalette(length(unique(cell_annot$annot)))
    }
    
    D = as.matrix(count_mat[,markers$gene]) %>%
        scale %>%
        reshape2::melt() %>%
        set_colnames(c('cell', 'gene', 'exp')) %>%
        inner_join(
            cell_annot, by = 'cell'
        ) %>%
        mutate(exp = ifelse(is.na(exp), 0, exp)) %>%
        inner_join(
            clone_post, by = 'cell'
        ) %>%
        left_join(markers, by = 'gene') %>%
        arrange(p_1) %>%
        mutate(cell = factor(cell, unique(cell)))

    p_markers = ggplot(
            D,
            aes(x = cell, y = gene, fill = exp)
        ) +
        geom_tile() +
        theme_classic() +
        theme(
            axis.text.x = element_blank(),
            axis.text.y = element_text(size = 7),
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.2, fill = NA),
            strip.background.x = element_blank(),
            strip.text.x = element_blank(),
            strip.background.y = element_rect(size = 0, fill = NA),
            strip.text.y.left = element_text(size = 6, angle = 0),
        ) +
        ylab('marker') +
        facet_grid(marker_type ~ cell_group, space = 'free_y', scale = 'free', switch="y") +
        scale_fill_gradient2(low = 'blue', mid = 'white', high = 'red', limits = c(-1.5,1.5), oob = scales::oob_squish)

    p_annot = ggplot(
            D,
            aes(x = cell, y = 'annot', fill = annot)
        ) +
        geom_tile() +
        theme_classic() +
        theme(
            axis.text.x = element_blank(),
            axis.text.y = element_text(size = 7),
            axis.ticks.x = element_blank(),
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.2, fill = NA),
            strip.background = element_rect(size = 0, fill = NA),
            strip.text = element_text(size = 6),
            axis.title.x = element_blank(),
            strip.text.x = element_blank()
        ) +
        ylab('') +
        facet_grid(~ cell_group, space = 'free_y', scale = 'free', switch="y") +
        scale_fill_manual(values = pal_annot) +
        guides(fill = guide_legend())

    p_cnv = ggplot(
            D %>% mutate(p_cnv = 1-p_1),
            aes(x = cell, y = 'cnv', fill = p_cnv)
        ) +
        geom_tile() +
        theme_classic() +
        theme(
            axis.text.x = element_blank(),
            axis.text.y = element_text(size = 7),
            axis.ticks.x = element_blank(),
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.2, fill = NA),
            strip.background = element_rect(size = 0, fill = NA),
            strip.text = element_text(size = 6),
            axis.title.x = element_blank()
        ) +
        ylab('') +
        facet_grid(~cell_group, space = 'free_y', scale = 'free', switch="y") +
        scale_fill_gradient2(low = 'blue', mid = 'white', high = 'red', midpoint = 0.5, limits = c(0,1), oob = scales::oob_squish) + 
        ggtitle(sample) +
        guides(fill = 'none')

    p_cnv/p_annot/p_markers + plot_layout(heights = c(0.5,0.5,10), guides = 'collect')
    
}

do_plot = function(p, f, w, h, out_dir = '~/figures') {
    ggsave(filename = paste0(out_dir, '/', f, '.png'), plot = p, width = w, height = h, device = 'png', dpi = 300)
    options(repr.plot.width = w, repr.plot.height = h, repr.plot.res = 300)
    print(p)
}


annot_bar = function(D, transpose = FALSE, legend = TRUE, legend_title = '') {
    p = ggplot(
        D,
        aes(x = cell, y = '', fill = annot)
    ) +
    geom_tile(width=1, height=0.9) +
    theme_void() +
    scale_y_discrete(expand = expansion(0)) +
    scale_x_discrete(expand = expansion(0)) +
    theme(
        panel.spacing = unit(0.1, 'mm'),
        panel.border = element_rect(size = 0, color = 'black', fill = NA),
        panel.background = element_rect(fill = 'white'),
        strip.background = element_blank(),
        strip.text = element_blank(),
        # axis.text = element_text(size = 8),
        axis.text = element_blank(),
        plot.margin = margin(0.5,0,0.5,0, unit = 'mm')
    ) 

    if (transpose) {
        p = p + coord_flip() +
            theme(plot.margin = margin(0,0.5,0,0.5, unit = 'mm'))
    }

    if (legend) {
        p = p + guides(fill = guide_legend(keywidth = unit(3, 'mm'), keyheight = unit(1, 'mm'), title = legend_title))
    } else {
        p = p + guides(fill = 'none')
    }

    return(p)
}

#' @export
cell_heatmap = function(geno, cnv_order = NULL, cell_order = NULL, limit = 5, cnv_type = TRUE) {

    # geno = geno %>% mutate(logBF = Z_cnv - Z_n)

    if (is.null(cnv_order)) {
        cnv_order = unique(geno$seg)
    }

    if (is.null(cell_order)) {
        cell_order = unique(geno$cell)
    }

    geno = geno %>% 
        filter(cell %in% cell_order) %>%
        filter(cnv_state != 'neu') %>%
        mutate(seg = factor(seg, cnv_order)) %>%
        arrange(seg) %>%
        mutate(seg_label = factor(seg_label, unique(seg_label))) %>%
        mutate(cell = factor(cell, cell_order))

    pal = RColorBrewer::brewer.pal(n = 8, 'Set1')

    if (!cnv_type) {
        geno = geno %>% mutate(seg_label = seg)
    }

    p_map = ggplot(
            geno,
            aes(x = cell, y = seg_label, fill = logBF)
        ) +
        geom_tile(width=0.4, height=0.9) +
        theme_classic() +
        scale_y_discrete(expand = expansion(0)) +
        scale_x_discrete(expand = expansion(add = 0.5)) +
        theme(
            panel.spacing = unit(0.1, 'mm'),
            # panel.border = element_rect(size = 0.5, color = 'black', fill = NA),
            axis.line.x = element_blank(),
            axis.line.y = element_blank(),
            axis.ticks.x = element_blank(),
            panel.border = element_blank(),
            panel.background = element_rect(fill = 'white'),
            strip.background = element_blank(),
            axis.text.x = element_blank(),
            strip.text = element_text(angle = 90, size = 8, vjust = 0.5),
            plot.margin = margin(0,0,0,0, unit = 'mm')
        ) +
        scale_fill_gradient2(low = pal[2], high = pal[1], midpoint = 0, limits = c(-limit, limit), oob = scales::oob_squish) +
        # xlab('') +
        theme(plot.title = element_blank()) +
        ylab('') +
        guides(fill = guide_colorbar(barwidth = unit(3, 'mm'), barheight = unit(15, 'mm')))

    return(p_map)
}

#' @export
plot_sc_roll = function(gexp.norm.long, hc, k, lim = 0.8, n_sample = 50) {

    cells = unique(gexp.norm.long$cell)
    
    cell_sample = sample(cells, min(n_sample, length(cells)), replace = FALSE)
        
    p_tree = ggtree(hc, size = 0.2)

    cell_order = p_tree$data %>% filter(isTip) %>% arrange(y) %>% pull(label)
    
    p_heatmap = gexp.norm.long %>%
        filter(cell %in% cell_sample) %>%
        mutate(cell = factor(cell, cell_order)) %>%
        mutate(cluster = cutree(hc, k = k)[as.character(cell)]) %>%
        arrange(cell) %>%
        mutate(cluster = factor(cluster, rev(unique(cluster)))) %>%
        ggplot(
            aes(x = gene_index, y = cell, fill = exp_rollmean)
        ) +
        geom_tile() +
        scale_fill_gradient2(low = 'blue', high = 'red', mid = 'white', midpoint = 0, limits = c(-lim,lim), oob = scales::squish) +
        theme_void() +
        scale_x_discrete(expand = expansion(0)) +
        scale_y_discrete(expand = expansion(0)) +
        theme(
            axis.text.y = element_blank(),
            legend.position = 'top',
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'wheat4', fill = NA)
        ) +
        facet_grid(cluster~CHROM, scale = 'free', space = 'free') +
        guides(fill = guide_legend(title = 'Expression\nmagnitude'))
    
    (p_tree | p_heatmap) + plot_layout(widths = c(1,10))
    # p_heatmap
    
}

#' @export
show_phasing = function(bulk, min_depth = 8, dot_size = 0.5, h = 50) {

    D = bulk %>% 
        filter(!is.na(pAD)) %>%
        group_by(CHROM) %>%
        mutate(pBAF = 1-pBAF, pAD = DP - pAD) %>%
        mutate(theta_ar_roll = theta_hat_roll(AD, DP-AD, h = h)) %>%
        mutate(theta_hat_roll = theta_hat_roll(pAD, DP-pAD, h = h)) %>%
        filter(DP >= min_depth) %>%
        mutate(snp_index = 1:n()) %>%
        mutate(dAR = 0.5+abs(AR-0.5)) %>%
        mutate(dAR_roll = caTools::runmean(abs(AR-0.5), align = 'center', k = 30))

    boundary = D %>% filter(boundary == 1) %>% pull(snp_index)
    
    p1 = D %>%
        mutate(state_post = 'neu') %>%
        ggplot(
            aes(x = snp_index, y = AR),
            na.rm=TRUE
        ) +
        geom_hline(yintercept = 0.5, linetype = 'dashed', color = 'gray') +
        geom_point(
            aes(color = state_post),
            size = dot_size,
        ) +
        # geom_line(
        #     aes(x = snp_index, y = 0.5 + dAR_roll), color = 'red'
        # ) +
        # geom_line(
        #     aes(x = snp_index, y = 0.5 - dAR_roll), color = 'red'
        # ) +
        # geom_line(
        #     aes(x = snp_index, y = 0.5 + theta_ar_roll), color = 'red'
        # ) +
        theme_classic() +
        theme(
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
            strip.background = element_blank(),
            axis.text.x = element_blank(),
            axis.title.x = element_blank()
        ) +
        scale_color_manual(values = cnv_colors, limits = force) +
        ylim(0,1) +
        facet_grid(.~CHROM, space = 'free_x', scale = 'free_x') +
        geom_vline(xintercept = boundary - 1, color = 'red', size = 0.5, linetype = 'dashed') +
        guides(color = 'none')

    p2 = D %>%
        mutate(state_post = 'neu') %>%
        ggplot(
            aes(x = snp_index, y = pBAF),
            na.rm=TRUE
        ) +
        geom_hline(yintercept = 0.5, linetype = 'dashed', color = 'gray') +
        geom_point(
            aes(color = ifelse(theta_hat_roll > 0, 'loh_1_up', 'loh_1_down')),
            size = dot_size,
        ) +
        geom_line(
            aes(x = snp_index, y = 0.5 + theta_hat_roll), color = 'red'
        ) +
        theme_classic() +
        theme(
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
            strip.background = element_blank()
        ) +
        scale_color_manual(values = cnv_colors) +
        ylim(0,1) +
        facet_grid(.~CHROM, space = 'free_x', scale = 'free_x') +
        geom_vline(xintercept = boundary - 1, color = 'red', size = 0.5, linetype = 'dashed') +
        guides(color = 'none')

    (p1 / p2) + plot_layout(guides = 'auto')
}

#' @export
plot_psbulk = function(Obs, dot_size = 0.8, dot_alpha = 0.5, exp_limit = 2, min_depth = 10, theta_roll = FALSE, fc_correct = TRUE, allele_only = FALSE, phi_mle = FALSE, use_pos = FALSE, legend = TRUE) {

    if (!'state_post' %in% colnames(Obs)) {
        Obs = Obs %>% mutate(state_post = state)
    }

    if (use_pos) {
        marker = 'POS'
        marker_label = 'Position'
    } else {
        marker = 'snp_index'
        marker_label = 'SNP index'
    }

    # fix retest states 
    Obs = Obs %>% 
        mutate(
            theta_level = ifelse(str_detect(state_post, '_2'), 2, 1),
            state_post = ifelse(
                cnv_state_post %in% c('amp', 'loh', 'del'),
                ifelse(p_up > 0.5, paste0(cnv_state_post, '_', theta_level, '_', 'up'), paste0(cnv_state_post, '_', theta_level, '_', 'down')),
                state_post
        ))

    # correct for baseline bias
    if (fc_correct & !allele_only) {
        Obs = Obs %>% mutate(logFC = logFC - mu)
    }

    D = Obs %>% 
        mutate(logFC = ifelse(logFC > exp_limit | logFC < -exp_limit, NA, logFC)) %>%
        mutate(pBAF = ifelse(DP >= min_depth, pBAF, NA)) %>%
        mutate(pHF = pBAF) %>%
        reshape2::melt(measure.vars = c('logFC', 'pHF'))

    if (allele_only) {
        D = D %>% filter(variable == 'pHF')
    }

    p = ggplot(
            D,
            aes(x = get(marker), y = value, color = state_post),
            na.rm=TRUE
        ) +
        geom_point(
            aes(
                shape = str_detect(state_post, '_2'),
                alpha = str_detect(state_post, '_2')
            ),
            size = dot_size,
            na.rm = TRUE
        ) +
        scale_alpha_discrete(range = c(dot_alpha, 1)) +
        scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 15)) +
        theme_classic() +
        theme(
            panel.spacing.x = unit(0, 'mm'),
            panel.spacing.y = unit(1, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
            strip.background = element_blank(),
            axis.text.x = element_blank()
        ) +
        facet_grid(variable ~ CHROM, scale = 'free', space = 'free_x') +
        # scale_x_continuous(expand = expansion(add = 5)) +
        scale_color_manual(values = cnv_colors, limits = force, na.translate = F) +
        guides(color = guide_legend(title = "", override.aes = aes(size = 3)), fill = FALSE, alpha = FALSE, shape = FALSE) +
        xlab(marker) +
        ylab('')

    if (!legend) {
        p = p + guides(color = FALSE, fill = FALSE, alpha = FALSE, shape = FALSE)
    }

    if (phi_mle) {
        segs = Obs %>% 
            distinct(CHROM, seg, seg_start, seg_start_index, seg_end, seg_end_index, phi_mle) %>%
            mutate(variable = 'logFC') %>%
            filter(log2(phi_mle) < exp_limit)

        if (use_pos) {
            start = 'seg_start'
            end = 'seg_end'
        } else {
            start = 'seg_start_index'
            end = 'seg_end_index'
        }

        p = p + geom_segment(
            inherit.aes = FALSE,
            data = segs,
            aes(x = get(start), xend = get(end), y = log2(phi_mle), yend = log2(phi_mle)),
            color = 'darkred',
            size = 0.5
        ) +
        geom_hline(data = data.frame(variable = 'logFC'), aes(yintercept = 0), color = 'gray30', linetype = 'dashed')
    } else if (!allele_only) {
        p = p + geom_line(
            inherit.aes = FALSE,
            data = Obs %>% mutate(variable = 'logFC') %>% filter(log2(phi_mle_roll) < exp_limit),
            aes(x = get(marker), y = log2(phi_mle_roll), group = '1'),
            color = 'darkred',
            size = 0.35
        ) +
        geom_hline(data = data.frame(variable = 'logFC'), aes(yintercept = 0), color = 'gray30', linetype = 'dashed')
    }

    if (theta_roll) {
        p = p + geom_line(
            inherit.aes = FALSE,
            data = D %>% mutate(variable = 'pHF'),
            aes(x = snp_index, y = 0.5 - theta_hat_roll, color = paste0(cnv_state_post, '_down')),
            # color = 'black',
            size = 0.35
        ) +
        geom_line(
            inherit.aes = FALSE,
            data = D %>% mutate(variable = 'pHF'),
            aes(x = snp_index, y = 0.5 + theta_hat_roll, color = paste0(cnv_state_post, '_up')),
            # color = 'gray',
            size = 0.35
        )
    } 

    p = p + xlab(marker_label)
    
    return(p)
}

#' @export
plot_bulks = function(bulk_all, min_depth = 8, dot_alpha = 0.5, fc_correct = TRUE, phi_mle = FALSE, allele_only = FALSE, use_pos = FALSE, ncol = 1, legend = TRUE, title = TRUE) {

    options(warn = -1)
    plot_list = bulk_all %>%
        split(.$sample) %>%
        lapply(
            function(bulk) {

                sample = unique(bulk$sample)
                n_cells = unique(bulk$n_cells)

                p = plot_psbulk(
                        bulk, 
                        dot_alpha = dot_alpha,
                        min_depth = min_depth, fc_correct = fc_correct,
                        phi_mle = phi_mle, use_pos = use_pos, legend = legend,
                        allele_only = allele_only
                    ) + 
                    theme(
                        title = element_text(size = 8),
                        axis.text.x = element_blank(),
                        axis.title = element_blank()
                    )

                if (title) {
                    p = p + ggtitle(glue('{sample} (n={n_cells})'))
                }
                    

                return(p)
            }
        )
    options(warn = 0)

    panel = wrap_plots(plot_list, ncol = ncol, guides = 'collect')

    return(panel)
}

#' @export
plot_exp = function(gexp_bulk, exp_limit = 3) {
    ggplot(
        gexp_bulk,
        aes(x = gene_index, y = logFC)
    ) +
    theme_classic() +
    geom_point(size = 1, color = 'gray', alpha = 0.8, pch = 16) +
    theme(
        panel.spacing = unit(0, 'mm'),
        panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
        strip.background = element_blank()
    ) +
    facet_grid(~CHROM, space = 'free_x', scale = 'free_x') +
    geom_hline(yintercept = 0, color = 'gray30', linetype = 'dashed') +
    geom_line(
        inherit.aes = FALSE,
        aes(x = gene_index, y = log2(phi_hat_roll), group = '1'),
        color = 'darkred',
        size = 0.35
    ) +
    ylim(-exp_limit, exp_limit)
}

#' @export
plot_segs_post = function(segs_consensus) {
    segs_consensus %>% 
        filter(cnv_state != 'neu') %>%
        mutate(seg_label = paste0(seg_cons, '_', cnv_state_post)) %>%
        mutate(seg_label = factor(seg_label, unique(seg_label))) %>%
        reshape2::melt(measure.vars = c('p_loh', 'p_amp', 'p_del', 'p_bamp', 'p_bdel'), value.name = 'p') %>%
        ggplot(
            aes(x = seg_label, y = variable, fill = p, label = round(p, 2))
        ) +
        theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
        geom_tile() +
        geom_text(color = 'white')
}

# model diagnostics
#' @export
plot_exp_post = function(exp_post, jitter = TRUE) {
    if (!'annot' %in% colnames(exp_post)) {
        exp_post$annot = '0'
    }
    p = exp_post %>%
        filter(n > 20) %>%
        mutate(seg_label = paste0(seg, '(', cnv_state, ')')) %>%
        mutate(seg_label = factor(seg_label, gtools::mixedsort(unique(seg_label)))) %>%
        ggplot(
            aes(x = seg_label, y = log2(phi_mle), fill = cnv_state, color = p_cnv)
        ) +
        geom_violin(size = 0) +
        geom_hline(yintercept = 0, color = 'green', linetype = 'dashed') +
        geom_hline(yintercept = log2(1.5), color = 'red', linetype = 'dashed') +
        geom_hline(yintercept = -1, color = 'blue', linetype = 'dashed') +
        facet_grid(annot~cnv_state, scale = 'free', space = 'free') +
        theme_classic() +
        theme(axis.text.x = element_text(angle = 30, hjust = 1)) +
        scale_fill_manual(values = cnv_colors)

    if (jitter) {
        p = p + geom_jitter(size = 0.1)
    }

    return(p)
}

#' @export
plot_clones = function(p_matrix, gtree, annot = TRUE, n_sample = 1e4, bar_ratio = 0.1, pal_clone = NULL, pal_annot = NULL) {

    if (is.null(pal_clone)) {
        pal_clone = c('gray', RColorBrewer::brewer.pal(n = 8, 'Set1'))
    }

    if (is.null(pal_annot)) {
        pal_annot = c('gray', RColorBrewer::brewer.pal(n = 8, 'Set1'))
    }

    p_matrix = p_matrix %>% 
        group_by(group) %>%
        filter(cell %in% sample(unique(cell), min(n_sample, length(unique(cell))))) %>%
        ungroup() %>%
        filter(cnv_state != 'neu')

    # ordering cells
    if (annot) {
        p_matrix = p_matrix %>% 
            arrange(group, annot) %>%
            mutate(cell = factor(cell, unique(cell)))
    } else {
        set.seed(0)
        p_matrix = p_matrix %>% 
            group_by(group) %>%
            sample_frac(1) %>%
            ungroup() %>%
            mutate(cell = factor(cell, unique(cell)))
    }
    
    # ordering cnvs
    cnv_order = gtree %>% 
            activate(nodes) %>%
            mutate(rank = dfs_rank(root = node_is_root())) %>%
            data.frame() %>%
            filter(!is.na(site)) %>%
            arrange(-rank) %>%
            pull(site) %>%
            map(function(x){rev(unlist(str_split(x, ',')))}) %>%
            unlist

    p_matrix = p_matrix %>%
        mutate(seg = factor(seg, cnv_order)) %>%
        arrange(seg) %>%
        mutate(seg_label = factor(seg_label, unique(seg_label)))  %>%
        mutate(group = factor(group))
    
    p = ggplot(
            p_matrix,
            aes(x = cell, y = seg_label, fill = logBF)
        ) +
        geom_tile(width=0.1, height=0.9) +
        theme_classic() +
        scale_y_discrete(expand = expansion(0)) +
        scale_x_discrete(expand = expansion(0)) +
        theme(
            panel.spacing = unit(0.1, 'mm'),
            panel.border = element_rect(size = 0.2, color = 'black', fill = NA),
            panel.background = element_rect(fill = 'white'),
            axis.line.x = element_blank(),
            axis.line.y = element_blank(),
            strip.background = element_blank(),
            strip.text = element_blank(),
            axis.text.x = element_blank(),
            axis.ticks.x = element_blank(),
            axis.title.x = element_blank(),
            plot.margin = margin(3,0,0,0, unit = 'pt')
            # strip.text = element_text(angle = 0, size = 8, vjust = 0.5)
        ) +
        facet_grid(.~group, scale = 'free', space = 'free') +
        scale_fill_gradient2(low = pal[2], high = pal[1], midpoint = 0, limits = c(-5, 5), oob = scales::oob_squish) +
        xlab('') +
        ylab('') +
        guides(fill = guide_colorbar(barwidth = unit(3, 'mm'), barheight = unit(15, 'mm')))

    p_clones = ggplot(
            p_matrix %>% distinct(cell, group),
            aes(x = cell, y = 'clone', fill = group)
        ) +
        geom_tile(width=1, height=0.9) +
        theme_void() +
        scale_y_discrete(expand = expansion(0)) +
        scale_x_discrete(expand = expansion(0)) +
        theme(
            panel.spacing = unit(0.1, 'mm'),
            panel.border = element_rect(size = 0, color = 'black', fill = NA),
            panel.background = element_rect(fill = 'white'),
            strip.background = element_blank(),
            strip.text = element_text(angle = 0, size = 10, vjust = 0.5),
            axis.text.y = element_text(size = 8)
        ) +
        facet_grid(.~group, scale = 'free', space = 'free') +
        xlab('') +
        ylab('') + 
        scale_fill_manual(values = pal_clone) +
        guides(fill = 'none')

    if (annot) {

        p_annot = ggplot(
                p_matrix %>% distinct(cell, group, annot),
                aes(x = cell, y = '', fill = annot)
            ) +
            geom_tile(width=1, height=0.9) +
            theme_void() +
            scale_y_discrete(expand = expansion(0)) +
            scale_x_discrete(expand = expansion(0)) +
            theme(
                panel.spacing = unit(0.1, 'mm'),
                panel.border = element_rect(size = 0, color = 'black', fill = NA),
                panel.background = element_rect(fill = 'white'),
                strip.background = element_blank(),
                strip.text = element_blank(),
                axis.text.y = element_text(size = 8),
                plot.margin = margin(3,0,0,0, unit = 'pt')
            ) +
            facet_grid(.~group, scale = 'free', space = 'free') +
            xlab('') +
            ylab('') +
            scale_fill_manual(values = pal_annot) +
            guides(fill = guide_legend(keywidth = unit(2, 'mm'), keyheight = unit(2, 'mm'), title = ''))

        return((p_clones / p_annot / p) + plot_layout(height = c(bar_ratio, bar_ratio, 1), guides = 'collect'))
        
    } else {
        return((p_clones / p) + plot_layout(height = c(1,10)))
    }
    
}

#' @export
plot_mut_history = function(G_m, horizontal = TRUE, label = TRUE, pal_clone = NULL) {

    G_m = label_genotype(G_m)

    if (is.null(pal_clone)) {
        getPalette = colorRampPalette(RColorBrewer::brewer.pal(n = 5, 'Spectral'))
        pal_clone = c('gray', getPalette(length(V(G_m))))
    }

    G_df = G_m %>% as_tbl_graph() %>% mutate(clone = factor(clone))

    if (!label) {
        G_df = G_df %>% activate(edges) %>% mutate(to_label = '')
    }

    p = G_df %>% 
        ggraph(layout = 'tree') + 
        geom_edge_link(
            aes(label = str_trunc(to_label, 20, side = 'center')),
            vjust = -1,
            arrow = arrow(length = unit(3, "mm")),
            end_cap = circle(4, 'mm'),
            start_cap = circle(4, 'mm')
        ) + 
        geom_node_point(aes(color = clone), size = 10) +
        geom_node_text(aes(label = clone), size = 6) +
        theme_void() +
        scale_x_continuous(expand = expansion(0.2)) +
        scale_y_continuous(expand = expansion(0.2)) + 
        scale_color_manual(values = pal_clone, limits = force) +
        guides(color = 'none')

    if (horizontal) {
        p = p + coord_flip() + scale_y_reverse(expand = expansion(0.2))
    }

    return(p)
}

getPalette = colorRampPalette(pal)

#' @export
plot_clone_panel = function(res, label = NULL, cell_annot = NULL, type = 'joint', ratio = 1, tvn = FALSE, tree = TRUE, p_min = 0.5, bar_ratio = 0.1, pal_clone = NULL, pal_annot = NULL) {

    if (is.null(pal_clone)) {
        n_clones = length(unique(res$clone_post$clone_opt))
        pal_clone = getPalette(max(V(res$G_m)-1, 8)) %>% c('gray', .) %>% setNames(1:n_clones)
    } 
    
    if (is.null(pal_annot) & !is.null(cell_annot)) {
        pal_annot = getPalette(length(unique(cell_annot$annot)))
    }
    

    if (type == 'joint') {
        p_matrix = res$joint_post
    } else if (type == 'allele') {
        p_matrix = res$allele_post
    } else {
        p_matrix = res$exp_post
    }

    if (!is.null(cell_annot)) {
        p_matrix = p_matrix %>% left_join(cell_annot, by = 'cell')
        annot = TRUE
    } else {
        annot = FALSE
    }

    if (!'p_opt' %in% colnames(res$clone_post)) {
        res$clone_post = res$clone_post %>% 
            rowwise() %>%
            mutate(p_opt = get(paste0('p_', clone_opt))) %>%
            ungroup()
    }

    if (tvn) {
        res$clone_post = res$clone_post %>%
            mutate(
                clone_opt = ifelse(clone_opt == 1, 'normal', 'tumor'),
                p_opt = ifelse(clone_opt == 'normal', p_1, 1-p_1)
            )
    }

    p_clones = p_matrix %>% 
        filter(seg %in% colnames(res$geno)) %>%
        inner_join(
            res$clone_post %>% filter(p_opt > p_min),
            by = 'cell'
        ) %>%
        mutate(group = clone_opt) %>%
        plot_clones(res$gtree, pal_clone = pal_clone, pal_annot = pal_annot, annot = annot, bar_ratio = bar_ratio)

    plot_title = plot_annotation(title = label, theme = theme(plot.title = element_text(hjust = 0.1)))

    if (tvn | (!tree)) {
        return(p_clones + plot_title)
    }

    p_mut = res$G_m %>% plot_mut_history(pal_clone = pal_clone) 

    (p_mut / p_clones) + plot_layout(heights = c(ratio, 1)) + plot_title
}

#' @export
tree_heatmap = function(joint_post, gtree, ratio = 1, limit = 5, cell_dict = NULL, cnv_order = NULL, label_mut = TRUE, cnv_type = TRUE, branch_width = 0.2, tip = T, tip_length = 0.5, pal_annot = NULL, pal_clone = NULL, layout = 'rect', tvn = FALSE, legend = T) {
    
    if (!'clone' %in% colnames(as.data.frame(activate(gtree, 'nodes')))) {
        gtree = gtree %>% activate(nodes) %>% mutate(clone = as.integer(as.factor(GT)))
    }

    gtree = mark_tumor_lineage(gtree)

    joint_post = joint_post %>% filter(cnv_state != 'neu')

    if (!'seg_label' %in% colnames(joint_post)) {
        joint_post = joint_post %>% mutate(seg_label = paste0(seg, '(', cnv_state, ')')) %>%
            mutate(seg_label = factor(seg_label, unique(seg_label)))
    }

    if (!'logBF' %in% colnames(joint_post)) {
        joint_post = joint_post %>% mutate(logBF = Z_cnv - Z_n)
    }

    if (tvn) {
        clone_dict = gtree %>%
            activate(nodes) %>%
            data.frame %>%
            mutate(compartment = factor(compartment)) %>%
            {setNames(.$compartment, .$name)}
    } else {
        clone_dict = gtree %>%
            activate(nodes) %>%
            data.frame %>%
            mutate(
                GT = ifelse(compartment == 'normal', '', GT),
                GT = factor(GT),
                clone = as.factor(clone)
            ) %>%
            {setNames(.$clone, .$name)}
    }

    getPalette = colorRampPalette(pal)

    if (is.null(pal_annot)) {
        pal_annot = getPalette(length(unique(cell_dict)))
    }

    if (is.null(pal_clone)) {
        pal_clone = getPalette(length(unique(clone_dict)))
    }

    OTU_dict = lapply(levels(clone_dict), function(x) names(clone_dict[clone_dict == x])) %>% setNames(levels(clone_dict))

    mut_nodes = gtree %>% activate(nodes) %>% filter(!is.na(site)) %>% data.frame() %>% select(name, site)

    gtree = gtree %>% activate(edges) %>% mutate(length = ifelse(leaf, pmax(length, tip_length), length))
    
    p_tree = gtree %>% 
        to_phylo() %>%
        groupOTU(
            OTU_dict,
            'clone'
        ) %>%
        ggtree(ladderize = T, size = branch_width, layout = layout) %<+%
        mut_nodes +
        layout_dendrogram() +
        # geom_rootedge(size = branch_width) +
        theme(
            plot.margin = margin(0,0,0,0),
            axis.title.x = element_blank(),
            axis.ticks.x = element_blank(),
            axis.text.x = element_blank(),
            axis.line.y = element_line(size = 0.2),
            axis.ticks.y = element_line(size = 0.2),
            # axis.text.y = element_text(size = 5)
            axis.text.y = element_blank()
        ) +
        guides(color = F) 

    if (tip) {
        p_tree = p_tree + geom_tippoint(aes(color = clone), size=0, stroke = 0.2) +
            scale_color_manual(values = c('gray', pal_clone), limits = force)
    }

    if (label_mut) {
        p_tree = p_tree + geom_point2(aes(subset = !is.na(site), x = branch), shape = 21, size = 1, fill = 'red') +
            geom_text2(
                aes(x = branch, label = str_trunc(site, 20, side = 'center')),
                size = 2, hjust = 0, vjust = -0.5, nudge_y = 1, color = 'darkred'
            )
    }
    
    if (legend) {
        p_tree = p_tree + 
            guides(color = guide_legend(keywidth = unit(3, 'mm'), override.aes = list(size = 2), keyheight = unit(1, 'mm'), title = NULL))
    }

    cell_order = p_tree$data %>% filter(isTip) %>% arrange(y) %>% pull(label)

    if (is.null(cnv_order)) {
        cnv_order = gtree %>% 
            activate(nodes) %>%
            mutate(rank = dfs_rank(root = node_is_root())) %>%
            data.frame() %>%
            filter(!is.na(site)) %>%
            arrange(-rank) %>%
            pull(site) %>%
            map(function(x){rev(unlist(str_split(x, ',')))}) %>%
            unlist
    }

    p_map = cell_heatmap(joint_post, cnv_order, cell_order, limit, cnv_type = cnv_type)

    p_clones = data.frame(
            cell = names(clone_dict),
            annot = unname(clone_dict)
        ) %>%
        mutate(cell = factor(cell, cell_order)) %>%
        annot_bar(transpose = F) +
        scale_fill_manual(values = c('gray', pal_clone))

    if (!is.null(cell_dict)) {
        p_annot = data.frame(
                cell = names(cell_dict),
                annot = unname(cell_dict)
            ) %>%
            mutate(cell = factor(cell, cell_order)) %>%
            annot_bar(transpose = F)
            # scale_fill_manual(values = pal_annot)

        panel = (p_tree / p_clones / p_annot / p_map) + plot_layout(heights = c(ratio,0.06,0.06,1), guides = 'collect')
    } else {
        panel = (p_tree / p_clones / p_map) + plot_layout(heights = c(ratio,0.1,1), guides = 'collect')
    }

    return(panel)
}

#' @export
plot_sc_joint = function(
        gtree, joint_post, segs_consensus, 
        cell_dict = NULL, size = 0.02, branch_width = 0.2, tip_length = 0.2, logBF_min = 1, p_min = 0.9,
        logBF_max = 5, clone_bar = FALSE, clone_legend = TRUE, clone_line = FALSE, pal_clone = NULL,
        multi_allelic = FALSE
    ) {

    if (!'clone' %in% colnames(as.data.frame(activate(gtree, 'nodes')))) {
        gtree = gtree %>% activate(nodes) %>% mutate(clone = as.integer(as.factor(GT)))
    }

    if (!'n_states' %in% colnames(segs_consensus)) {
        segs_consensus = segs_consensus %>% mutate(
            n_states = ifelse(cnv_state == 'neu', 1, 0), 
            cnv_states = cnv_state
        )
    }

    gtree = mark_tumor_lineage(gtree)

    gtree = gtree %>% activate(edges) %>% mutate(length = ifelse(leaf, pmax(length, tip_length), length))

    # plot phylogeny 
    p_tree = gtree %>% 
            to_phylo() %>%
            ggtree(ladderize = T, size = branch_width) +
            # geom_rootedge(size = branch_width) +
            theme(
                plot.margin = margin(0,1,0,0, unit = 'mm'),
                axis.title.x = element_blank(),
                axis.ticks.x = element_blank(),
                axis.text.x = element_blank(),
                axis.line.y = element_blank(),
                axis.ticks.y = element_blank(),
                # axis.text.y = element_text(size = 5)
                axis.text.y = element_blank()
            ) +
            guides(color = F)

    cell_order = p_tree$data %>% filter(isTip) %>% arrange(y) %>% pull(label)

    joint_post = joint_post %>% 
            inner_join(
                segs_consensus %>% select(seg = seg_cons, CHROM, seg_start, seg_end, n_states, cnv_states),
                by = c('seg', 'CHROM')
            ) %>%
            mutate(cell = factor(cell, cell_order)) %>%
            mutate(cell_index = as.integer(droplevels(cell))) 

    if (multi_allelic) {
        joint_post = joint_post %>% mutate(cnv_state = ifelse(n_states > 1, cnv_state_map, cnv_state))
    }

    # add clone lines
    if (clone_line) {

        leafs = res[[sample]]$gtree %>% 
                activate(nodes) %>% 
                filter(leaf) %>%
                as.data.frame()

        clones = unique(leafs$clone)
        clones = clones[clones != 1]

        clone_indices = sapply(
            clones,
            function(c) {                
                
                clone_cells = leafs %>% filter(clone == c) %>% pull(name)
                
                first_clone_index = which(cell_order %in% clone_cells)[1]

                return(first_clone_index)
                
            }
        )
    } else {
        clone_indices = c()
    }

    # add tumor vs normal line
    tumor_cells = gtree %>% 
        activate(nodes) %>% filter(leaf) %>%
        as.data.frame() %>% 
        filter(compartment == 'tumor') %>%
        pull(name)

    first_tumor_index = which(cell_order %in% tumor_cells)[1]

    chrom_labeller <- function(chr){
        # chr[as.integer(chr) %% 2 == 0] = ''
        chr[chr %in% c(19, 21, 22)] = ''
        return(chr)
    }

    # plot CNVs
    p_segs = ggplot(
            joint_post %>% mutate(
                cnv_state = ifelse(cnv_state == 'neu', NA, cnv_state),
                logBF = pmax(pmin(logBF, logBF_max), logBF_min),
                p_cnv = pmax(p_cnv, p_min),
            )
        ) +
        theme_classic() +
        geom_segment(
            aes(x = seg_start, xend = seg_end, y = cell_index, yend = cell_index, color = cnv_state, alpha = p_cnv),
            size = size
        ) +
        geom_segment(
            inherit.aes = F,
            aes(x = seg_start, xend = seg_end, y = 1, yend = 1),
            data = segs_consensus, size = 0, color = 'white', alpha = 0
        ) +
        geom_hline(yintercept = c(first_tumor_index, clone_indices), color = 'royalblue', size = 0.5, linetype = 'dashed') +
        # geom_hline(yintercept = c(first_tumor_index, clone_indices), color = 'gray', size = 0.5, linetype = 'solid') +
        theme(
            panel.spacing = unit(0, 'mm'),
            panel.border = element_rect(size = 0.5, color = 'gray', fill = NA),
            strip.background = element_blank(),
            axis.text = element_blank(),
            axis.title = element_blank(),
            axis.ticks = element_blank(),
            plot.margin = margin(0,0,5,0, unit = 'mm'),
            axis.line = element_blank()
        ) +
        scale_x_continuous(expand = expansion(0)) +
        scale_y_continuous(expand = expansion(0)) +
        facet_grid(.~CHROM, space = 'free', scale = 'free', labeller = labeller(CHROM = chrom_labeller)) +
        scale_alpha_continuous(range = c(0,1)) +
        guides(
            alpha = 'none',
            # alpha = guide_legend(),
            color = guide_legend(override.aes = c(size = 1), title = 'CNV state')
        ) +
        scale_color_manual(
            values = c('amp' = 'darkred', 'del' = 'darkblue', 'bamp' = cnv_colors[['bamp']], 'loh' = 'darkgreen', 'bdel' = 'blue'),
            labels = c('amp' = 'AMP', 'del' = 'DEL', 'bamp' = 'BAMP', 'loh' = 'CNLoH', 'bdel' = 'BDEL'),
            limits = force,
            na.translate = F
        )

    # clone annotation
    clone_dict = gtree %>%
        activate(nodes) %>%
        data.frame %>%
        mutate(
            GT = ifelse(compartment == 'normal', '', GT),
            GT = factor(GT),
            clone = ifelse(compartment == 'normal', 1, clone),
            clone = as.factor(clone)
        ) %>%
        {setNames(.$clone, .$name)}

    if (is.null(pal_clone)) {
        getPalette = colorRampPalette(RColorBrewer::brewer.pal(n = 10, 'Spectral'))
        pal_clone = c('gray', getPalette(length(unique(clone_dict))))
    }

    p_clone = data.frame(
            cell = names(clone_dict),
            annot = unname(clone_dict)
        ) %>%
        mutate(cell = factor(cell, cell_order)) %>%
        annot_bar(transpose = T, legend = clone_legend, legend_title = 'Clone') +
        scale_fill_manual(values = pal_clone)

    # external annotation
    if (!is.null(cell_dict)) {
        
        p_annot = data.frame(
                cell = names(cell_dict),
                annot = unname(cell_dict)
            ) %>%
            filter(cell %in% joint_post$cell) %>%
            mutate(cell = factor(cell, cell_order)) %>%
            annot_bar(transpose = T, legend_title = 'Annotation')

        if (clone_bar) {
            (p_tree | p_clone | p_annot | p_segs) + plot_layout(widths = c(1, 0.25, 0.25, 15), guides = 'collect')
        } else {
            (p_tree | p_annot | p_segs) + plot_layout(widths = c(1, 0.25, 15), guides = 'collect')
        }
    } else if (clone_bar) {
        (p_tree | p_clone | p_segs) + plot_layout(widths = c(1, 0.25, 15), guides = 'collect')
    } else {
        (p_tree | p_segs) + plot_layout(widths = c(1, 15), guides = 'collect')
    }
}