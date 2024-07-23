pkg load statistics

conversion_block = 17283233;

A = load("witness_size.run5.1.csv");
B = load("witness_size.run5.2.csv");
C = load("witness_size.run5.3.csv");

subplot(1,3,1);boxplot(A(:,2));ylim([0 max(A(:,2))]);xlim([0 2]);title('spec')
subplot(1,3,2);boxplot(B(:,2));ylim([0 max(A(:,2))]);xlim([0 2]);title('type 1')
subplot(1,3,3);boxplot(C(:,2));ylim([0 max(A(:,2))]);xlim([0 2]);title('type 2')
axes('Position', [0, 0, 1, 1], 'Visible', 'off');
text(0.5, 0.03, 'Comparison of witness sizes, during/post-transition', 'FontSize', 14, 'HorizontalAlignment', 'center');
print('total.png', '-dpng');

% from now on, only display the last 2 as the "default one" didn't complete the transition

subplot(1,2,1);boxplot(B(B(:,1)<conversion_block,2));ylim([0 max(B(:,2))]);xlim([0 2]);title('transition');
subplot(1,2,2);boxplot(B(B(:,1)>conversion_block,2));ylim([0 max(B(:,2))]);xlim([0 2]);title('post-transition');
axes('Position', [0, 0, 1, 1], 'Visible', 'off');
text(0.5, 0.03, 'Comparison of type 1 witness sizes', 'FontSize', 14, 'HorizontalAlignment', 'center');
print('compare_pre_post_transition_type_1.png', '-dpng');

subplot(1,2,1);boxplot(C(C(:,1)<conversion_block,2));ylim([0 max(C(:,2))]);xlim([0 2]);title('transition');
subplot(1,2,2);boxplot(C(C(:,1)>conversion_block,2));ylim([0 max(C(:,2))]);xlim([0 2]);title('post-transition');
axes('Position', [0, 0, 1, 1], 'Visible', 'off');
text(0.5, 0.03, 'Comparison of type 2 witness sizes', 'FontSize', 14, 'HorizontalAlignment', 'center');
print('compare_pre_post_transition_type_2.png', '-dpng');

subplot(1,2,1);boxplot(B(B(:,1)>conversion_block,2));ylim([0 max(B(:,2))]);xlim([0 2]);title('type 1');
subplot(1,2,2);boxplot(C(C(:,1)>conversion_block,2));ylim([0 max(B(:,2))]);xlim([0 2]);title('type 2');
axes('Position', [0, 0, 1, 1], 'Visible', 'off');
text(0.5, 0.03, 'Comparison of witness sizes post-transition', 'FontSize', 14, 'HorizontalAlignment', 'center');
print('compare_post_transition.png', '-dpng');
