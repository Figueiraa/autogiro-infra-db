-- ═══════════════════════════════════════════════════════════════════════════
-- Dados de demonstração
--
-- O schema sozinho não permite demonstrar o sistema: a autenticação por CPF
-- consulta a tabela `clients` e, sem nenhum cliente cadastrado, todo login
-- responde 401 corretamente — mas o fluxo de sucesso nunca aparece.
--
-- Todos os CPFs abaixo são válidos pelos dígitos verificadores (módulo 11) e
-- fictícios: foram gerados aleatoriamente, não pertencem a pessoas reais.
--
-- Idempotente como as demais migrations: `ON CONFLICT DO NOTHING` nas chaves
-- naturais (CPF, placa, nome do serviço) permite reaplicar sem erro nem
-- duplicação.
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Clientes ──────────────────────────────────────────────────────────────
INSERT INTO clients (name, cpf_cnpj, phone, email, address) VALUES
    ('Maria Oliveira',      '44232322191', '11987654321', 'maria.oliveira@exemplo.com.br',  'Rua das Acácias, 120 - São Paulo/SP'),
    ('João Pereira',        '83406290426', '11976543210', 'joao.pereira@exemplo.com.br',    'Av. Brasil, 4500 - São Paulo/SP'),
    ('Ana Beatriz Souza',   '21476245355', '21965432109', 'ana.souza@exemplo.com.br',       'Rua Dias da Cruz, 88 - Rio de Janeiro/RJ'),
    ('Carlos Menezes',      '78965651530', '31954321098', 'carlos.menezes@exemplo.com.br',  'Rua Sapucaí, 310 - Belo Horizonte/MG'),
    ('Transportes Lima ME', '94789277879', '41943210987', 'contato@transporteslima.com.br', 'Rod. BR-116, km 22 - Curitiba/PR')
ON CONFLICT (cpf_cnpj) DO NOTHING;

-- ─── Veículos ──────────────────────────────────────────────────────────────
-- O client_id é resolvido pelo CPF, para não depender da ordem dos SERIAL.
INSERT INTO vehicles (plate, brand, model, year, client_id)
SELECT v.plate, v.brand, v.model, v.year, c.id
FROM (VALUES
    ('RTA1B23', 'Volkswagen', 'Gol 1.6',        2019, '44232322191'),
    ('SDF4G56', 'Fiat',       'Argo Drive',     2021, '44232322191'),
    ('QWE7H89', 'Chevrolet',  'Onix LT',        2020, '83406290426'),
    ('ZXC0J12', 'Toyota',     'Corolla XEi',    2022, '21476245355'),
    ('POI3K45', 'Honda',      'Civic EXL',      2018, '78965651530'),
    ('LKJ6M78', 'Renault',    'Master Furgão',  2023, '94789277879')
) AS v (plate, brand, model, year, cpf)
JOIN clients c ON c.cpf_cnpj = v.cpf
ON CONFLICT (plate) DO NOTHING;

-- ─── Tipos de serviço ──────────────────────────────────────────────────────
INSERT INTO service_types (name, description, price, estimated_duration_minutes) VALUES
    ('Troca de óleo e filtro',    'Óleo sintético 5W30 e filtro de óleo',                149.90,  45),
    ('Alinhamento e balanceamento', 'Alinhamento 3D das quatro rodas e balanceamento',   189.90,  60),
    ('Revisão completa',          'Checklist de 40 itens, fluidos e filtros',            499.90, 240),
    ('Troca de pastilhas de freio', 'Substituição das pastilhas dianteiras',             320.00,  90),
    ('Diagnóstico eletrônico',    'Leitura de códigos de falha via scanner OBD-II',       99.90,  30),
    ('Troca de correia dentada',  'Correia dentada, tensor e bomba d''água',             890.00, 300)
ON CONFLICT (name) DO NOTHING;

-- ─── Peças e insumos ───────────────────────────────────────────────────────
-- `parts` não tem chave natural única no schema, então a inserção é guardada
-- por NOT EXISTS para manter a idempotência.
INSERT INTO parts (name, description, unit_price, stock_quantity, unit)
SELECT p.name, p.description, p.unit_price, p.stock_quantity, p.unit
FROM (VALUES
    ('Óleo sintético 5W30',      'Litro de óleo sintético para motor',        45.90, 120, 'L'),
    ('Filtro de óleo',           'Filtro de óleo universal linha leve',       32.50,  80, 'un'),
    ('Filtro de ar',             'Filtro de ar do motor',                     58.00,  60, 'un'),
    ('Pastilha de freio dianteira', 'Jogo de pastilhas cerâmicas',           210.00,  35, 'jg'),
    ('Correia dentada',          'Correia dentada com tensor',               340.00,  15, 'un'),
    ('Bomba d''água',            'Bomba d''água para linha leve',            275.00,  12, 'un'),
    ('Fluido de freio DOT4',     'Frasco de 500 ml',                          38.90,  50, 'un'),
    ('Palheta limpador 24"',     'Palheta dianteira 24 polegadas',            42.00,  40, 'un')
) AS p (name, description, unit_price, stock_quantity, unit)
WHERE NOT EXISTS (
    SELECT 1 FROM parts existente WHERE existente.name = p.name
);
