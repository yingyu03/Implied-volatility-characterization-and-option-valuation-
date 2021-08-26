clear all;clc;close all;
%% ������ %read data
data = xlsread('2020_09.xlsx');range = 2:size(data);
Strike_all = data(range, 1);MarketPrice_all= data(range,2);AssetPrice_all= data(range, 11);Time_all=data(range, 9);Rate_all= data(range, 10);
%Delta_all=data(range,3);Gamma_all=data(range,4); Vega_all=data(range,5); Theta_all=data(range,6); Rho_all=data(range,7);
%% BS-HVģ�� %BS-HV model
%%��ʷ�����ʶ�ȡ read historical volatility data which caculated in excel
HV1_all= data(range, 15);%21��
HV2_all= data(range, 16);%63��
HV3_all= data(range, 17);%126��
HV4_all= data(range, 18);%189��
HV5_all= data(range, 19);%252��
HV6_all= data(range, 20);%100�� % abandon at last
Strike=[];MarketPrice=[]; AssetPrice=[];Rate=[];Time=[];
HV1=[]; HV2=[]; HV3=[]; HV4=[]; HV5=[]; HV6=[];
% select the data that satisify with c>=max(ST-K,0)
for i=1:length(range)
    if MarketPrice_all(i)>=max(AssetPrice_all(i)-Strike_all(i)*exp(-Rate_all(i)*Time_all(i)))
       Strike=[Strike;Strike_all(i)];MarketPrice=[MarketPrice;MarketPrice_all(i)]; 
       AssetPrice=[AssetPrice;AssetPrice_all(i)];Rate=[Rate;Rate_all(i)];
       Time=[Time;Time_all(i)];
       HV1=[HV1;HV1_all(i)];HV2=[HV2;HV2_all(i)];HV3=[HV3;HV3_all(i)];HV4=[HV4;HV4_all(i)];HV5=[HV5;HV5_all(i)];HV6=[HV6;HV6_all(i)];
    end
end
%��ʷ��������ģ�͹�����Ȩģ�ͼ۸� caculate the option price by the BS-HV model
Call1 = blsprice(AssetPrice,Strike, Rate, Time, HV1);
Call2 = blsprice(AssetPrice,Strike, Rate, Time, HV2);
Call3 = blsprice(AssetPrice,Strike, Rate, Time, HV3);
Call4 = blsprice(AssetPrice,Strike, Rate, Time, HV4);
Call5 = blsprice(AssetPrice,Strike, Rate, Time, HV5);
Call6 = blsprice(AssetPrice,Strike, Rate, Time, HV6);
%% BS-IVģ�� %BS-IV model
%���������������IV 
ImpliedVolatility= blsimpv(AssetPrice,Strike,Rate,Time, MarketPrice);
%��ά��ͼ����������� (not in paper)
scatter3(Time,Strike, ImpliedVolatility,'.');
xlabel('STRIKE');ylabel('MATURITY');zlabel('IMPLIED VOLATILITY');
%% figure 11 % ���г�������������������ͼ 
for i = 1:length(Time)
    a1 = round(Time(i)*252);
    if Strike(i)>3
        a2= round(14+(Strike(i)-3)./0.1);
    else
        a2=round((Strike(i)-2.3)./0.05);
    end
    IMPLIEDVALATILITY(a1,a2)=ImpliedVolatility(i);
end

for i=1:175
    for j=1:23
        if IMPLIEDVALATILITY(i,j)==0
           IMPLIEDVALATILITY(i,j)=nan;
        end
    end
end
STRIKE= [2.35,2.4,2.45,2.5,2.55,2.6,2.65,2.7,2.75,2.8,2.85,2.9,2.95,3,3.1,3.2,3.3,3.4,3.5,3.6,3.7,3.8,3.9];
TIME = 1/252:1/252:175/252;
[STRIKE_SURF,TIME_SURF] = meshgrid(STRIKE,TIME);
surf(TIME_SURF,STRIKE_SURF, IMPLIEDVALATILITY);
xlabel('MATURITY');ylabel('STRIKE');zlabel('IMPLIED VOLATILITY');
%% figure12~14 ��ֵ��APP curve fitting
[fitresult, gof] = createFit(Time, Strike, ImpliedVolatility);
%��ֵ���沨���ʶ�ȡ read volatility from surface 
f=fit([Strike,Time],ImpliedVolatility,'thinplateinterp'); 
%��ֵ�����ʴ���BS������Ȩģ�ͼ۸� estimate option price by BS-IV model
Call7 = blsprice(AssetPrice,Strike, Rate, Time, f(Strike,Time));
%% Heston lsqnonlin��������С���˷� calibration (Table 5)
t = zeros(size(Time));
q = zeros(size(Time));
PC = ones(size(Time));
%v0,theta,rho,kappa,sigma
%startparameters = [0.04, 0.1, 0.1, 1, 1];
%startparameters = [0.1, 0.5, -0.1,2,2 ];
%startparameters = [0.04, 1, 1,10,10 ];
startparameters = [0.04, 0.1,1,2,2 ];
%startparameters = [0.036 0.1 0.08 5 5 ];
%options = optimoptions('lsqnonlin', 'Display', 'iter');
options = optimoptions('lsqnonlin', 'Algorithm','trust-region-reflective')
tic
[xopt,fval] = lsqnonlin(@(x) Heston1993KahlJaeckelLordRev3(PC,AssetPrice,Strike,Time,t,Rate,q,x(1),x(2),x(3),x(4),x(5)) - MarketPrice,...
    startparameters,[eps eps -1+eps eps eps  ], [Inf Inf 1-eps Inf  Inf], options);
toc
disp(['Optimal parameter vector: ' num2str(xopt)]);
%������Ȩ�۸� Heston model price  
xopt=[0.0380,0.1171,0.0388,1.7304,1.6231];
Call8 = Heston1993KahlJaeckelLordRev3(PC,AssetPrice,Strike,Time,t,Rate,q,xopt(1),xopt(2),xopt(3),xopt(4),xopt(5));
Call8(find(Call8<0),1)=0;
%% ����ƫ�� ERROR (Table 4)
Call = [Call1,Call2,Call3,Call4,Call5,Call6,Call7,Call8];
for i=1:8
    ME(i)=mean(Call(:,i)-MarketPrice);
    MRE(i)=mean((Call(:,i)-MarketPrice)./MarketPrice);
    MSE(i)=mean((Call(:,i)-MarketPrice).^2);
    RMSE(i)=sqrt(mean((Call(:,i)-MarketPrice).^2));
    MAE(i)=mean(abs(Call(:,i)-MarketPrice));
    MARE(i)=mean(abs((Call(:,i)-MarketPrice)./MarketPrice));
    SMAPE(i)=mean(abs(Call(:,i)-MarketPrice)./(abs(Call(:,i)+abs(MarketPrice))./2));
end
ERROR1_8= [ME;MRE;MSE;RMSE;MAE;MARE;SMAPE];%ѡ�����ŵ�����
%% �Ա� ��IV��HV 
BS_IV=blsimpv(AssetPrice,Strike,Rate,Time, Call7);
Heston_IV=blsimpv(AssetPrice,Strike,Rate,Time, Call8);
% figure 16
plot(ImpliedVolatility,'b.-');hold on;plot(HV5,'r--');hold on;plot(BS_IV,'g-.');hold on;plot(Heston_IV,'k-');hold on;
legend({'Market-IV', 'HV(252)', 'BS-IV','Heston-IV'});xlabel('All Data');ylabel('Volatility');
% figure 9
plot(ImpliedVolatility,'.-');hold on;plot(HV1);hold on;plot(HV2);hold on;plot(HV3);hold on;plot(HV4);hold on;plot(HV5);hold on;
legend({'Market-IV', 'HV(21)', 'HV(63)', 'HV(126)', 'HV(189)','HV(252)'});xlabel('All Data');ylabel('Volatility');
% figure 10
HV1_7_7=[];HV2_7_7=[];HV3_7_7=[];HV4_7_7=[];HV5_7_7=[];HV6_7_7=[];ImpliedVolatility_7_7=[];Strike_7_7=[];
for i=1:length(Time)
    if Time(i)==57./252
        HV1_7_7=[HV1_7_7,HV1(i)];
        HV2_7_7=[HV2_7_7,HV2(i)];      
        HV3_7_7=[HV3_7_7,HV3(i)];      
        HV4_7_7=[HV4_7_7,HV4(i)];
        HV5_7_7=[HV5_7_7,HV5(i)];
        Strike_7_7=[Strike_7_7,Strike(i)];
        ImpliedVolatility_7_7=[ImpliedVolatility_7_7,ImpliedVolatility(i)];
    end
end
plot(Strike_7_7,ImpliedVolatility_7_7,'b.-');
hold on
plot(Strike_7_7,HV1_7_7,'.-');
hold on
plot(Strike_7_7,HV2_7_7,'.-');
hold on
plot(Strike_7_7,HV3_7_7,'.-');
hold on
plot(Strike_7_7,HV4_7_7,'.-');
hold on
plot(Strike_7_7,HV5_7_7,'.-');
hold on
hold on
legend('Market-IV','HV(21)','HV(63)','HV(126)','HV(189)','HV(252)', 'location','best');
xlabel('Strike');ylabel('Volatility');  
title('Date:2020-07-07')
%% �Ա� ��IVs
% figure 17
HV5_7_7=[];BS_IV_7_7=[]; Heston_IV_7_7=[];ImpliedVolatility_7_7=[];
for i=1:length(Time)
    if Time(i)==57./252
        HV5_7_7=[HV5_7_7,HV5(i)];
        BS_IV_7_7=[BS_IV_7_7,BS_IV(i)];
        Heston_IV_7_7=[Heston_IV_7_7,Heston_IV(i)];
        ImpliedVolatility_7_7=[ImpliedVolatility_7_7,ImpliedVolatility(i)];
    end
end
plot(Strike_7_7,ImpliedVolatility_7_7,'b.-');
hold on
plot(Strike_7_7,HV5_7_7,'r--');
hold on
plot(Strike_7_7,BS_IV_7_7,'g-.');
hold on
plot(Strike_7_7,Heston_IV_7_7,'k-');
hold on
legend('Market-IV', 'HV(252)', 'BS-IV','Heston-IV' ,'location','best');
xlabel('Strike');ylabel('Volatility');  
title('Date:2020-07-07')

